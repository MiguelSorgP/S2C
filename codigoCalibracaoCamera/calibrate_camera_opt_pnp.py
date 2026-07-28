#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Calibracao de camera por ChArUco OTIMIZADA por Erro 3D de PnP (Mestrado - IPS Tela-Camera).
VERSÃO ULTRA-ACELERADA (GPU CUDA + CPU Multi-threaded + Cache Inteligente).

Processa VIDEO(S) de calibracao gravado(s) e busca a selecao otimizada de frames que
minimiza o erro medio de posicionamento 3D de PnP em relacao ao conjunto de dados ROI ground-truth.

Uso:
  python codigoCalibracaoCamera/calibrate_camera_opt_pnp.py
  python codigoCalibracaoCamera/calibrate_camera_opt_pnp.py --video codigoCalibracaoCamera/videos/meu_video.mp4
  python codigoCalibracaoCamera/calibrate_camera_opt_pnp.py --roi-csv resultadosROI/resultados_ROI_otsu05_2007.csv --iterations 3000
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed
import csv
from datetime import datetime
import glob
import json
import math
import os
import pickle
import random
import sys
import time
import traceback

import numpy as np

# Verificar disponibilidade do PyTorch com CUDA (RTX 3050)
try:
    import torch
    HAS_TORCH = True
    HAS_CUDA = torch.cuda.is_available()
except ImportError:
    HAS_TORCH = False
    HAS_CUDA = False

# ---------------------------------------------------------------------------
# CONFIGURACOES E PARAMETROS DE OTIMIZACAO (EDITAVEIS NO TOPO DO CODIGO)
# ---------------------------------------------------------------------------
DEFAULT_ROI_CSV = "resultadosROI/resultados_ROI_otsu05_2007_clean.csv"
MIN_CHARUCO_CORNERS = 12          # cantos minimos por frame para aceitar a view
DEFAULT_EVERY = 5                 # amostrar 1 a cada N frames do video para ter um pool amplo de views
MIN_VIEWS_OPT = 10                # minimo de views no subconjunto otimizado
MAX_VIEWS_OPT = 40                # maximo de views no subconjunto otimizado
NUM_SEARCH_ITERATIONS = 3000      # numero de iteracoes da busca estocastica/local
TARGET_SIDE_M = 0.2403            # lado do quadrado da ROI física em metros (24.03 cm)

RMS_ACCEPTABLE = 1.5              # limite de erro RMS de reprojecao para considerar a calibracao valida


class TeeLogger(object):
    """Duplica a saida de sys.stdout para a tela e para um arquivo de texto."""
    def __init__(self, filepath):
        self.terminal = sys.stdout
        self.file = open(filepath, "w", encoding="utf-8")

    def write(self, message):
        try:
            self.terminal.write(message)
        except Exception:
            pass
        try:
            self.file.write(message)
        except Exception:
            pass

    def flush(self):
        try:
            self.terminal.flush()
        except Exception:
            pass
        try:
            self.file.flush()
        except Exception:
            pass

    def close(self):
        try:
            self.file.close()
        except Exception:
            pass


def require_opencv():
    """Exige OpenCV >= 4.7 com o modulo aruco."""
    try:
        import cv2
    except ImportError:
        sys.exit(
            "ERRO: nao foi possivel importar 'cv2'.\n"
            "Instale o pacote CONTRIB: pip install \"opencv-contrib-python>=4.7\""
        )
    version = cv2.__version__
    try:
        major, minor = (int(x) for x in version.split(".")[:2])
    except ValueError:
        sys.exit("ERRO: versao do OpenCV nao reconhecida: %r" % version)
    if (major, minor) < (4, 7):
        sys.exit("ERRO: este script exige OpenCV >= 4.7. Versao encontrada: %s" % version)
    if not hasattr(cv2, "aruco") or not hasattr(cv2.aruco, "CharucoDetector"):
        sys.exit("ERRO: cv2.aruco.CharucoDetector ausente.")
    return cv2, version


def load_board(cv2, config):
    """Reconstroi o CharucoBoard a partir do config."""
    dict_name = config["dictionary_name"]
    dict_id = getattr(cv2.aruco, dict_name)
    squares_x = int(config["squaresX"])
    squares_y = int(config["squaresY"])
    square_len = float(config["square_length_m"])
    marker_len = float(config["marker_length_m"])

    dictionary = cv2.aruco.getPredefinedDictionary(dict_id)
    board = cv2.aruco.CharucoBoard(
        (squares_x, squares_y), square_len, marker_len, dictionary
    )
    return board, dict_name, dict_id, squares_x, squares_y, square_len, marker_len


def load_roi_dataset(roi_csv_path):
    """Carrega o arquivo CSV de ROI contendo coordenadas em pixels e ground-truth 3D."""
    if not os.path.isfile(roi_csv_path):
        raise FileNotFoundError(f"Arquivo CSV de ROI nao encontrado: {roi_csv_path}")

    rows = []
    with open(roi_csv_path, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            try:
                row_data = {
                    "video_name": r.get("video_name", ""),
                    "x_position": float(r["x_position"]),
                    "y_position": float(r["y_position"]),
                    "z_position": float(r["z_position"]),
                    "distance": float(r["distance"]),
                    "x_tl": float(r["x_tl"]), "y_tl": float(r["y_tl"]),
                    "x_tr": float(r["x_tr"]), "y_tr": float(r["y_tr"]),
                    "x_br": float(r["x_br"]), "y_br": float(r["y_br"]),
                    "x_bl": float(r["x_bl"]), "y_bl": float(r["y_bl"]),
                }
                rows.append(row_data)
            except (KeyError, ValueError):
                continue

    if not rows:
        raise ValueError(f"Nenhum registro valido lido de {roi_csv_path}")
    return rows


class FastPnPEvaluator:
    """
    Avaliador de Erro PnP 3D otimizado (Multi-threaded CPU & GPU PyTorch CUDA).
    Pre-aloca os arrays do dataset ROI para evitar sobrecarga de criacao de objetos.
    """
    def __init__(self, roi_rows, target_side_m=TARGET_SIDE_M, device="auto", num_workers=None):
        self.roi_rows = roi_rows
        self.N = len(roi_rows)
        self.target_side_m = target_side_m
        half_side = target_side_m / 2.0

        self.world_pts = np.array([
            [-half_side,  half_side, 0.0],  # TL
            [ half_side,  half_side, 0.0],  # TR
            [ half_side, -half_side, 0.0],  # BR
            [-half_side, -half_side, 0.0]   # BL
        ], dtype=np.float64)

        # Matrizes pre-estruturadas
        self.img_pts_all = np.zeros((self.N, 4, 2), dtype=np.float64)
        self.gt_pos_all = np.zeros((self.N, 3), dtype=np.float64)

        for i, row in enumerate(roi_rows):
            self.img_pts_all[i] = [
                [row["x_tl"], row["y_tl"]],
                [row["x_tr"], row["y_tr"]],
                [row["x_br"], row["y_br"]],
                [row["x_bl"], row["y_bl"]]
            ]
            self.gt_pos_all[i] = [row["x_position"], row["z_position"], row["y_position"]]

        self.num_workers = num_workers or max(1, os.cpu_count() or 4)
        
        # GPU Setup
        if device == "cuda" or (device == "auto" and HAS_CUDA):
            self.use_gpu = True
            self.device_obj = torch.device("cuda")
            self.gt_pos_gpu = torch.tensor(self.gt_pos_all, dtype=torch.float32, device=self.device_obj)
            self.img_pts_gpu = torch.tensor(self.img_pts_all, dtype=torch.float32, device=self.device_obj)
            self.world_pts_gpu = torch.tensor(self.world_pts, dtype=torch.float32, device=self.device_obj)
        else:
            self.use_gpu = False

    def evaluate_single_row(self, cv2, K, dist_coeffs, i):
        """Avalia 1 linha do dataset ROI via OpenCV PnP."""
        img_pts = self.img_pts_all[i]
        gt_x, gt_y, gt_z = self.gt_pos_all[i]

        ok, rvec, tvec = cv2.solvePnP(self.world_pts, img_pts, K, dist_coeffs, flags=cv2.SOLVEPNP_IPPE_SQUARE)
        if not ok:
            ok, rvec, tvec = cv2.solvePnP(self.world_pts, img_pts, K, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE)

        if not ok or tvec is None:
            return None

        tx, ty, tz = float(tvec[0, 0]), float(tvec[1, 0]), float(tvec[2, 0])
        err_x = abs(tx - gt_x)
        err_y = abs(ty - gt_y)
        err_z = abs(tz - gt_z)
        err_3d = math.sqrt(err_x**2 + err_y**2 + err_z**2)
        return err_3d, err_x, err_y, err_z

    def evaluate(self, cv2, K, dist):
        """
        Avalia o erro medio 3D PnP utilizando multi-threading no C++ do OpenCV (libera GIL).
        """
        dist_coeffs = np.array(dist[:5], dtype=np.float64)

        # Usar ThreadPoolExecutor para rodar solvePnP em paralelo no C++ da OpenCV
        with ThreadPoolExecutor(max_workers=min(32, self.num_workers)) as executor:
            futures = [
                executor.submit(self.evaluate_single_row, cv2, K, dist_coeffs, i)
                for i in range(self.N)
            ]
            results = [f.result() for f in futures]

        valid_res = [r for r in results if r is not None]
        if not valid_res:
            return float("inf"), float("inf"), float("inf"), float("inf")

        res_arr = np.array(valid_res)
        mean_3d = float(np.mean(res_arr[:, 0]))
        mean_x = float(np.mean(res_arr[:, 1]))
        mean_y = float(np.mean(res_arr[:, 2]))
        mean_z = float(np.mean(res_arr[:, 3]))
        return mean_3d, mean_x, mean_y, mean_z


def evaluate_pnp_3d_error(cv2, K, dist, roi_rows, target_side_m=TARGET_SIDE_M, evaluator=None):
    """Funcao de compatibilidade mantendo assinatura original."""
    if evaluator is None:
        evaluator = FastPnPEvaluator(roi_rows, target_side_m=target_side_m)
    return evaluator.evaluate(cv2, K, dist)


def run_calibration_on_subset(cv2, board, subset_indices, candidate_views, image_size):
    """Roda cv2.calibrateCamera sobre um subconjunto especifico de views de calibracao."""
    obj_points = []
    img_points = []
    corner_xy_list = []

    for idx in subset_indices:
        view = candidate_views[idx]
        c, i, op, ip = view["corners"], view["ids"], view["op"], view["ip"]
        obj_points.append(op)
        img_points.append(ip)
        corner_xy_list.append(c.reshape(-1, 2))

    if len(obj_points) < 4:
        return None

    try:
        rms, K, dist, rvecs, tvecs = cv2.calibrateCamera(
            obj_points, img_points, image_size, None, None
        )
        if K is None or K[0, 0] <= 0 or K[1, 1] <= 0:
            return None

        dist_flat = dist.reshape(-1)
        return {
            "rms": float(rms),
            "K": K,
            "dist": dist_flat,
            "rvecs": rvecs,
            "tvecs": tvecs,
            "corner_xy_list": corner_xy_list,
            "num_views": len(subset_indices)
        }
    except Exception:
        return None


def process_single_video_opt(
    video_path, config, board, dict_name, dict_id, squares_x, squares_y,
    square_len, marker_len, roi_csv_path, roi_rows, every, min_views, max_views,
    iterations, outputs_base_dir, matrizes_dir, cv2, opencv_version,
    force_redetect=False, num_workers=None, device="auto"
):
    video_name = os.path.basename(video_path)
    video_stem = os.path.splitext(video_name)[0]

    # Subpasta com sufixo 'opt'
    video_out_dir = os.path.join(outputs_base_dir, f"{video_stem}_opt")
    os.makedirs(video_out_dir, exist_ok=True)
    os.makedirs(matrizes_dir, exist_ok=True)

    console_log_path = os.path.join(video_out_dir, "console_output_opt.txt")
    logger = TeeLogger(console_log_path)
    orig_stdout = sys.stdout
    sys.stdout = logger

    try:
        print("\n" + "#" * 72)
        print("PROCESSANDO VÍDEO COM OTIMIZAÇÃO 3D PNP (VERSÃO ACELERADA): %s" % video_name)
        print("#" * 72)
        print("Caminho do vídeo: %s" % video_path)
        print("Pasta de saída: %s" % video_out_dir)
        print("Dataset ROI ground-truth: %s (%d registros)" % (roi_csv_path, len(roi_rows)))
        print("Aceleração GPU PyTorch/CUDA: %s" % ("ATIVA (RTX 3050)" if (HAS_CUDA and device != "cpu") else "Desativada / CPU"))

        evaluator = FastPnPEvaluator(roi_rows, target_side_m=TARGET_SIDE_M, device=device, num_workers=num_workers)

        cache_path = os.path.join(video_out_dir, "views_cache.pkl")
        candidate_views = []
        image_size = None
        w, h = 0, 0
        sampled = 0

        # --- TENTAR CARREGAR DO CACHE BINARIO FAST .PKL ---
        use_cache = False
        if not force_redetect and os.path.isfile(cache_path):
            try:
                with open(cache_path, "rb") as f:
                    cache_data = pickle.load(f)
                if cache_data.get("every") == every and cache_data.get("video_name") == video_name:
                    candidate_views = cache_data["candidate_views"]
                    image_size = cache_data["image_size"]
                    w, h = image_size
                    sampled = cache_data.get("sampled", len(candidate_views) * every)
                    use_cache = True
                    print("\n⚡ [CACHE HIT] Views do vídeo carregadas instantaneamente do arquivo cache:")
                    print("   - %s (%d views válidas acumuladas)" % (cache_path, len(candidate_views)))
            except Exception as e:
                print("   ! Falha ao carregar cache, re-extraindo do vídeo: %s" % e)

        # --- EXTRAÇÃO DO VÍDEO CASO NÃO ESTEJA EM CACHE ---
        if not use_cache:
            print("\n🎥 Extraindo views do vídeo (sampling 1 a cada %d frames)..." % every)
            detector = cv2.aruco.CharucoDetector(board)
            cap = cv2.VideoCapture(video_path)
            if not cap.isOpened():
                print("ERRO: nao foi possivel abrir o video: %s" % video_path)
                return False

            w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            print("Video: %dx%d, ~%d frames" % (w, h, total_frames))
            image_size = (w, h)

            frame_idx = -1
            sampled = 0
            start_ext = time.time()

            while True:
                ok, frame = cap.read()
                if not ok:
                    break
                frame_idx += 1
                if frame_idx % every != 0:
                    continue
                sampled += 1

                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                det_res = detector.detectBoard(gray)
                ch_corners = det_res[0] if (det_res is not None and len(det_res) > 0) else None
                ch_ids = det_res[1] if (det_res is not None and len(det_res) > 1) else None

                if ch_ids is None or len(ch_ids) < MIN_CHARUCO_CORNERS:
                    continue

                if hasattr(board, "matchImagePoints"):
                    match_res = board.matchImagePoints(ch_corners, ch_ids)
                    if match_res is not None and len(match_res) >= 2:
                        op, ip = match_res[0], match_res[1]
                    else:
                        op, ip = None, None
                else:
                    op, ip = None, None

                if op is None or len(op) < MIN_CHARUCO_CORNERS:
                    continue

                candidate_views.append({
                    "frame_idx": frame_idx,
                    "corners": ch_corners,
                    "ids": ch_ids,
                    "op": op,
                    "ip": ip,
                    "frame_sample": frame.copy() if len(candidate_views) == 0 else None
                })

            cap.release()
            ext_time = time.time() - start_ext
            print("Extração concluída em %.2f s | Frames amostrados: %d | Views válidas: %d" % (ext_time, sampled, len(candidate_views)))

            # Salvar cache para execuções futuras
            try:
                cache_data = {
                    "video_name": video_name,
                    "image_size": image_size,
                    "every": every,
                    "sampled": sampled,
                    "candidate_views": candidate_views
                }
                with open(cache_path, "wb") as f:
                    pickle.dump(cache_data, f, protocol=pickle.HIGHEST_PROTOCOL)
                print("💾 Cache de detecções salvo em: %s" % cache_path)
            except Exception as e:
                print("   ! Aviso: nao foi possivel salvar cache: %s" % e)

        M = len(candidate_views)
        if M < min_views:
            print("ERRO: views validas insuficientes (%d < min %d) para calibrar." % (M, min_views))
            return False

        # --- AVALIAR CALIBRAÇÃO BASELINE ---
        baseline_indices = list(range(min(M, max_views)))
        baseline_res = run_calibration_on_subset(cv2, board, baseline_indices, candidate_views, image_size)

        if baseline_res is None:
            print("ERRO na calibracao baseline.")
            return False

        base_mean_3d, base_x, base_y, base_z = evaluator.evaluate(cv2, baseline_res["K"], baseline_res["dist"])
        print("\n--- RESULTADO BASELINE (Amostragem Padrao %d views) ---" % len(baseline_indices))
        print("RMS Reproj: %.4f px" % baseline_res["rms"])
        print("K Baseline: fx=%.2f, fy=%.2f, cx=%.2f, cy=%.2f"
              % (baseline_res["K"][0, 0], baseline_res["K"][1, 1], baseline_res["K"][0, 2], baseline_res["K"][1, 2]))
        print("Erro Medio 3D PnP: %.4f m (%.2f cm) [X: %.2f cm, Y: %.2f cm, Z: %.2f cm]"
              % (base_mean_3d, base_mean_3d * 100, base_x * 100, base_y * 100, base_z * 100))

        # --- ALGORITMO DE OTIMIZACAO ACELERADO ---
        print("\n" + "=" * 72)
        print("INICIANDO BUSCA OTIMIZADA DE SUBCONJUNTO DE FRAMES (PARALELA / ACELERADA)...")
        print("Teto de iteracoes: %d | Faixa de views: [%d, %d]" % (iterations, min_views, min(M, max_views)))
        print("=" * 72)

        start_time = time.time()
        best_indices = list(baseline_indices)
        best_res = baseline_res
        best_err_3d = base_mean_3d
        best_err_xyz = (base_x, base_y, base_z)

        # Passo A: Busca Gulosa de Remocao (Backward Elimination)
        current_indices = list(range(M))
        print("\n[Passo 1/2] Busca Gulosa de Remocao (Backward Elimination) a partir de %d views..." % M)

        curr_res = run_calibration_on_subset(cv2, board, current_indices, candidate_views, image_size)
        if curr_res is not None:
            curr_err_3d, curr_x, curr_y, curr_z = evaluator.evaluate(cv2, curr_res["K"], curr_res["dist"])
            if curr_err_3d < best_err_3d:
                best_err_3d = curr_err_3d
                best_indices = list(current_indices)
                best_res = curr_res
                best_err_xyz = (curr_x, curr_y, curr_z)
                print("  -> [GULOSO INICIAL] Todas as %d views: Erro 3D = %.4f m (%.2f cm) | RMS = %.4f px"
                      % (M, best_err_3d, best_err_3d * 100, best_res["rms"]))

        improved = True
        step_count = 0
        workers_count = num_workers or max(1, os.cpu_count() or 4)

        while improved and len(current_indices) > min_views:
            improved = False
            best_removal_idx = None
            total_cand = len(current_indices)
            print("  -> [GULOSO Rodada %d] Avaliando remocao de 1 view em paralelo (%d candidatos, %d workers)..."
                  % (step_count + 1, total_cand, workers_count))

            cands_to_eval = []
            for idx in current_indices:
                cand = [i for i in current_indices if i != idx]
                cands_to_eval.append((idx, cand))

            def _eval_removal(item):
                rem_idx, cand_indices = item
                c_res = run_calibration_on_subset(cv2, board, cand_indices, candidate_views, image_size)
                if c_res is None or c_res["rms"] > RMS_ACCEPTABLE:
                    return rem_idx, cand_indices, None, float("inf"), None
                err_3d, ex, ey, ez = evaluator.evaluate(cv2, c_res["K"], c_res["dist"])
                return rem_idx, cand_indices, c_res, err_3d, (ex, ey, ez)

            with ThreadPoolExecutor(max_workers=min(16, workers_count)) as pool:
                results = list(pool.map(_eval_removal, cands_to_eval))

            for rem_idx, cand_indices, c_res, err_3d, err_xyz in results:
                if c_res is not None and err_3d < best_err_3d:
                    best_err_3d = err_3d
                    best_removal_idx = rem_idx
                    best_indices = list(cand_indices)
                    best_res = c_res
                    best_err_xyz = err_xyz
                    improved = True

            if best_removal_idx is not None:
                current_indices.remove(best_removal_idx)
                step_count += 1
                print("  -> [GULOSO Rodada %d CONCLUIDA] Removida view. Views restantes: %d | Erro 3D: %.4f m (%.2f cm) | RMS: %.4f px"
                      % (step_count, len(current_indices), best_err_3d, best_err_3d * 100, best_res["rms"]))
            else:
                print("  -> [GULOSO] Nenhuma remocao isolada reduziu o Erro 3D. Encerrando Passo 1.")

        print("[Passo 1/2 Concluido] Subconjunto guloso ajustado para %d views (Menor Erro 3D: %.2f cm)"
              % (len(best_indices), best_err_3d * 100))

        # Passo B: Busca Local Estocastica / Monte Carlo Paralela em Batches
        max_k = min(M, max_views)
        print("\n[Passo 2/2] Iniciando Busca Estocastica / Monte Carlo Paralela (%d iteracoes)..." % iterations)
        log_interval = max(1, iterations // 10)
        batch_size = 64

        tested_count = 0
        iterations_done = 0

        def _eval_monte_carlo_batch(cand_batch):
            batch_results = []
            for cand_indices in cand_batch:
                c_res = run_calibration_on_subset(cv2, board, cand_indices, candidate_views, image_size)
                if c_res is None or c_res["rms"] > RMS_ACCEPTABLE:
                    batch_results.append((cand_indices, None, float("inf"), None))
                    continue
                err_3d, ex, ey, ez = evaluator.evaluate(cv2, c_res["K"], c_res["dist"])
                batch_results.append((cand_indices, c_res, err_3d, (ex, ey, ez)))
            return batch_results

        with ThreadPoolExecutor(max_workers=min(16, workers_count)) as pool:
            while iterations_done < iterations:
                current_batch_size = min(batch_size, iterations - iterations_done)
                cand_batch = []
                for _ in range(current_batch_size):
                    if random.random() < 0.7 and len(best_indices) >= min_views:
                        k = random.randint(min_views, max_k)
                        cand_set = set(best_indices)
                        n_mut = min(len(cand_set), random.randint(1, 3))
                        to_remove = random.sample(list(cand_set), n_mut)
                        for r in to_remove:
                            cand_set.remove(r)
                        available = set(range(M)) - cand_set
                        n_add = k - len(cand_set)
                        if n_add > 0 and len(available) >= n_add:
                            to_add = random.sample(list(available), n_add)
                            cand_set.update(to_add)
                        cand_indices = sorted(list(cand_set))
                    else:
                        k = random.randint(min_views, max_k)
                        cand_indices = sorted(random.sample(range(M), k))

                    if len(cand_indices) >= min_views:
                        cand_batch.append(cand_indices)

                chunk_size = max(1, len(cand_batch) // workers_count)
                chunks = [cand_batch[i:i + chunk_size] for i in range(0, len(cand_batch), chunk_size)]

                future_results = [pool.submit(_eval_monte_carlo_batch, chunk) for chunk in chunks]

                for f in future_results:
                    res_list = f.result()
                    for cand_indices, c_res, err_3d, err_xyz in res_list:
                        tested_count += 1
                        iterations_done += 1

                        if c_res is not None and err_3d < best_err_3d:
                            best_err_3d = err_3d
                            best_indices = list(cand_indices)
                            best_res = c_res
                            best_err_xyz = err_xyz
                            print("  -> [NOVO MELHOR %d/%d] Subconjunto de %d views | Novo Erro 3D: %.4f m (%.2f cm) | RMS: %.4f px"
                                  % (iterations_done, iterations, len(best_indices), best_err_3d, best_err_3d * 100, best_res["rms"]))
                        elif iterations_done % log_interval == 0:
                            print("  -> [PROGRESSO %d/%d (%.0f%%)] Melhor Erro 3D ate agora: %.2f cm (%d views | RMS: %.4f px)"
                                  % (iterations_done, iterations, (iterations_done / iterations) * 100, best_err_3d * 100, len(best_indices), best_res["rms"]))

        elapsed = time.time() - start_time
        print("\n🚀 Busca concluida em %.2f segundos (%d combinacoes testadas em paralelo)." % (elapsed, tested_count))

        # Extrair variaveis da melhor calibracao
        K_opt = best_res["K"]
        dist_opt = best_res["dist"]
        rms_opt = best_res["rms"]
        num_views_opt = len(best_indices)
        fx, fy = float(K_opt[0, 0]), float(K_opt[1, 1])
        cx, cy = float(K_opt[0, 2]), float(K_opt[1, 2])
        opt_x, opt_y, opt_z = best_err_xyz

        # --- RELATORIO COMPARATIVO ---
        print("\n" + "=" * 72)
        print("RESUMO COMPARATIVO DE CALIBRAÇÃO")
        print("=" * 72)
        print("Baseline (padrao)   : Erro 3D = %.4f m (%.2f cm) | RMS = %.4f px | %d views"
              % (base_mean_3d, base_mean_3d * 100, baseline_res["rms"], len(baseline_indices)))
        print("Otimizado (PnP 3D)  : Erro 3D = %.4f m (%.2f cm) | RMS = %.4f px | %d views"
              % (best_err_3d, best_err_3d * 100, rms_opt, num_views_opt))

        reduc_pct = ((base_mean_3d - best_err_3d) / base_mean_3d) * 100
        print(">> REDUÇÃO NO ERRO MÉDIO 3D: %.2f%%" % reduc_pct)
        print("\nDetalhamento dos Erros por Eixo (Otimizado):")
        print("  -> Erro Medio em X (horizontal) : %.4f m (%.2f cm)" % (opt_x, opt_x * 100))
        print("  -> Erro Medio em Y (vertical)   : %.4f m (%.2f cm)" % (opt_y, opt_y * 100))
        print("  -> Erro Medio em Z (profundid.) : %.4f m (%.2f cm)" % (opt_z, opt_z * 100))

        print("\nMatriz K Otimizada:")
        print("  fx = %.4f,  fy = %.4f" % (fx, fy))
        print("  cx = %.4f,  cy = %.4f" % (cx, cy))
        print("Distorcao [k1, k2, p1, p2, k3]: [%s]"
              % ", ".join("%.5f" % v for v in dist_opt[:5]))

        # --- SALVAR ARQUIVOS DE SAIDA ---
        calib_json_path = os.path.join(video_out_dir, "camera_calib_opt.json")
        undist_png_path = os.path.join(video_out_dir, "undistort_check_opt.png")
        matriz_m_path = os.path.join(matrizes_dir, f"calibracao_{video_stem}_opt.m")

        calib_data = {
            "video_source": video_name,
            "image_size": [w, h],
            "fx": fx, "fy": fy, "cx": cx, "cy": cy,
            "camera_matrix": K_opt.tolist(),
            "dist_coeffs": dist_opt[:5].tolist(),
            "dist_coeffs_labels": ["k1", "k2", "p1", "p2", "k3"],
            "rms_reprojection_error": float(rms_opt),
            "pnp_mean_3d_error_m": float(best_err_3d),
            "pnp_mean_3d_error_cm": float(best_err_3d * 100),
            "num_views_used": num_views_opt,
            "optimized_subset_indices": best_indices,
            "calibration_method": "Optimization by PnP 3D Error Minization (Fast GPU/CPU)",
            "opencv_version": opencv_version,
            "roi_csv_used": roi_csv_path
        }

        with open(calib_json_path, "w", encoding="utf-8") as f:
            json.dump(calib_data, f, indent=2, ensure_ascii=False)

        sample_frame = candidate_views[best_indices[0]]["frame_sample"]
        if sample_frame is None and len(candidate_views) > 0:
            sample_frame = candidate_views[0]["frame_sample"]

        if sample_frame is not None:
            undistorted = cv2.undistort(sample_frame, K_opt, dist_opt[:5])
            lbl = sample_frame.copy()
            cv2.putText(lbl, "ORIGINAL", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 2, cv2.LINE_AA)
            cv2.putText(undistorted, "UNDISTORT OPT", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2, cv2.LINE_AA)
            side_by_side = np.hstack([lbl, undistorted])
            cv2.imwrite(undist_png_path, side_by_side)

        now_str = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        m_lines = [
            "% --- PARÂMETROS DE CALIBRAÇÃO ÓTIMOS PNP 3D (GERADO AUTOMATICAMENTE) ---",
            f"% Data de geração: {now_str}",
            f"% Arquivo de origem: {video_name}",
            f"% Erro Médio 3D PnP: {float(best_err_3d*100):.2f} cm ({float(best_err_3d):.4f} m)",
            f"% Erro Reprojeção RMS: {float(rms_opt):.4f} px",
            f"% Views Utilizadas: {num_views_opt} (de {M} disponiveis)",
            "",
            "% Matriz Intrínseca da Câmera (K)",
            "K = [",
            f"    {K_opt[0, 0]:14.6f}, {K_opt[0, 1]:14.6f}, {K_opt[0, 2]:14.6f};",
            f"    {K_opt[1, 0]:14.6f}, {K_opt[1, 1]:14.6f}, {K_opt[1, 2]:14.6f};",
            f"    {K_opt[2, 0]:14.6f}, {K_opt[2, 1]:14.6f}, {K_opt[2, 2]:14.6f}",
            "];",
            "",
            "% Coeficientes de Distorção da Lente [k1, k2, p1, p2, k3]",
            f"distCoeffs = [{dist_opt[0]:.6f}, {dist_opt[1]:.6f}, {dist_opt[2]:.6f}, {dist_opt[3]:.6f}, {dist_opt[4]:.6f}];",
            ""
        ]
        with open(matriz_m_path, "w", encoding="utf-8") as f:
            f.write("\n".join(m_lines))

        print("\nArquivos salvos:")
        print("  - JSON: %s" % calib_json_path)
        print("  - Imagem Undistort: %s" % undist_png_path)
        print("  - Matriz MATLAB (.m): %s" % matriz_m_path)
        print("=" * 72)
        return True

    except Exception as e:
        print("ERRO INESPERADO ao processar %s:" % video_name)
        traceback.print_exc()
        return False

    finally:
        sys.stdout = orig_stdout
        logger.close()


def main():
    cv2, opencv_version = require_opencv()

    here = os.path.dirname(os.path.abspath(__file__))     # <raiz>/codigoCalibracaoCamera
    root = os.path.dirname(here)                            # <raiz>
    default_videos_dir = os.path.join(here, "videos")
    outputs_base_dir = os.path.join(here, "outputs")
    matrizes_dir = os.path.join(root, "matrizesCalibracao")
    default_config = os.path.join(here, "charuco_config.json")
    default_roi_csv = os.path.join(root, DEFAULT_ROI_CSV)

    parser = argparse.ArgumentParser(
        description="Calibracao de camera por ChArUco OTIMIZADA por erro 3D de PnP (Fast GPU/CPU)."
    )
    parser.add_argument(
        "--video",
        default=None,
        help="Caminho de um video (.mp4) ou pasta com videos (default: codigoCalibracaoCamera/videos)",
    )
    parser.add_argument(
        "--roi-csv",
        default=default_roi_csv,
        help="Caminho do arquivo CSV de ROI (default: resultadosROI/resultados_ROI_20_07_selecaoManual.csv)",
    )
    parser.add_argument(
        "--config",
        default=default_config,
        help="Caminho do charuco_config.json (default: codigoCalibracaoCamera/charuco_config.json)",
    )
    parser.add_argument(
        "--every", type=int, default=DEFAULT_EVERY,
        help=f"Amostrar 1 a cada N frames (default: {DEFAULT_EVERY})",
    )
    parser.add_argument(
        "--min-views", type=int, default=MIN_VIEWS_OPT,
        help=f"Minimo de views a usar no subconjunto (default: {MIN_VIEWS_OPT})",
    )
    parser.add_argument(
        "--max-views", type=int, default=MAX_VIEWS_OPT,
        help=f"Teto de views a usar no subconjunto (default: {MAX_VIEWS_OPT})",
    )
    parser.add_argument(
        "--iterations", type=int, default=NUM_SEARCH_ITERATIONS,
        help=f"Numero de iteracoes da busca estocastica (default: {NUM_SEARCH_ITERATIONS})",
    )
    parser.add_argument(
        "--force-redetect", action="store_true",
        help="Força a re-extração das views do vídeo ignorando o arquivo views_cache.pkl",
    )
    parser.add_argument(
        "--num-workers", type=int, default=None,
        help="Número de workers paralelos para calibração CPU (default: autodetectar núcleos)",
    )
    parser.add_argument(
        "--device", choices=["auto", "cuda", "cpu"], default="auto",
        help="Dispositivo de aceleração para PnP ('auto', 'cuda' para GPU RTX, 'cpu')",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.config):
        sys.exit("ERRO: config nao encontrado: %s" % args.config)

    with open(args.config, encoding="utf-8") as f:
        config = json.load(f)

    try:
        roi_rows = load_roi_dataset(args.roi_csv)
    except Exception as e:
        sys.exit(f"ERRO ao carregar arquivo de ROI: {e}")

    board, dict_name, dict_id, squares_x, squares_y, square_len, marker_len = load_board(
        cv2, config
    )

    video_target = args.video if args.video else default_videos_dir
    video_files = []

    if os.path.isfile(video_target):
        video_files = [video_target]
    elif os.path.isdir(video_target):
        valid_exts = ("*.mp4", "*.avi", "*.mov", "*.mkv", "*.m4v")
        for ext in valid_exts:
            video_files.extend(glob.glob(os.path.join(video_target, ext)))
            video_files.extend(glob.glob(os.path.join(video_target, ext.upper())))
        video_files = sorted(list(set(video_files)))

    if not video_files:
        sys.exit("ERRO: nenhum video encontrado em '%s'" % video_target)

    print("Encontrado(s) %d video(s) para calibrar com otimizacao PnP." % len(video_files))

    successes = 0
    for idx, v_path in enumerate(video_files, 1):
        print("\n[%d/%d] Processando: %s" % (idx, len(video_files), os.path.basename(v_path)))
        ok = process_single_video_opt(
            video_path=v_path,
            config=config,
            board=board,
            dict_name=dict_name,
            dict_id=dict_id,
            squares_x=squares_x,
            squares_y=squares_y,
            square_len=square_len,
            marker_len=marker_len,
            roi_csv_path=args.roi_csv,
            roi_rows=roi_rows,
            every=args.every,
            min_views=args.min_views,
            max_views=args.max_views,
            iterations=args.iterations,
            outputs_base_dir=outputs_base_dir,
            matrizes_dir=matrizes_dir,
            cv2=cv2,
            opencv_version=opencv_version,
            force_redetect=args.force_redetect,
            num_workers=args.num_workers,
            device=args.device
        )
        if ok:
            successes += 1

    print("\n" + "=" * 72)
    print("CONCLUÍDO: %d de %d vídeo(s) processado(s) com sucesso." % (successes, len(video_files)))
    print("=" * 72)


if __name__ == "__main__":
    main()
