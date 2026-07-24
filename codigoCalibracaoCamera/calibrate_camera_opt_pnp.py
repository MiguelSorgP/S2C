#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Calibracao de camera por ChArUco OTIMIZADA por Erro 3D de PnP (Mestrado - IPS Tela-Camera).

Processa VIDEO(S) de calibracao gravado(s) e busca a selecao otimizada de frames que
minimiza o erro medio de posicionamento 3D de PnP em relacao ao conjunto de dados ROI ground-truth.

Uso:
  python codigoCalibracaoCamera/calibrate_camera_opt_pnp.py
  python codigoCalibracaoCamera/calibrate_camera_opt_pnp.py --video codigoCalibracaoCamera/videos/meu_video.mp4
  python codigoCalibracaoCamera/calibrate_camera_opt_pnp.py --roi-csv resultadosROI/resultados_ROI_otsu05_2007.csv --iterations 3000
"""

import argparse
import csv
from datetime import datetime
import glob
import json
import math
import os
import random
import sys
import time
import traceback

# ---------------------------------------------------------------------------
# CONFIGURACOES E PARAMETROS DE OTIMIZACAO (EDITAVEIS NO TOPO DO CODIGO)
# ---------------------------------------------------------------------------
DEFAULT_ROI_CSV = "resultadosROI/resultados_ROI_otsu05_2007.csv"
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
            except (KeyError, ValueError) as e:
                continue

    if not rows:
        raise ValueError(f"Nenhum registro valido lido de {roi_csv_path}")
    return rows


def evaluate_pnp_3d_error(cv2, K, dist, roi_rows, target_side_m=TARGET_SIDE_M):
    """
    Calcula o Erro Medio de Posicionamento 3D (em metros) sobre o dataset de ROI usando PnP.
    
    Coordenadas no referencial da camera (tvec):
      - tx (X_cam): deslocamento horizontal (corresponde a x_position)
      - ty (Y_cam): deslocamento vertical (corresponde a z_position)
      - tz (Z_cam): profundidade perpendicular (corresponde a y_position)
    """
    import numpy as np

    half_side = target_side_m / 2.0
    world_pts = np.array([
        [-half_side,  half_side, 0.0],  # TL
        [ half_side,  half_side, 0.0],  # TR
        [ half_side, -half_side, 0.0],  # BR
        [-half_side, -half_side, 0.0]   # BL
    ], dtype=np.float64)

    dist_coeffs = np.array(dist[:5], dtype=np.float64)
    errors_3d = []
    errors_x = []
    errors_y = []
    errors_z = []

    for row in roi_rows:
        img_pts = np.array([
            [row["x_tl"], row["y_tl"]],
            [row["x_tr"], row["y_tr"]],
            [row["x_br"], row["y_br"]],
            [row["x_bl"], row["y_bl"]]
        ], dtype=np.float64)

        ok, rvec, tvec = cv2.solvePnP(world_pts, img_pts, K, dist_coeffs, flags=cv2.SOLVEPNP_IPPE_SQUARE)
        if not ok:
            ok, rvec, tvec = cv2.solvePnP(world_pts, img_pts, K, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE)

        if not ok or tvec is None:
            continue

        tx = float(tvec[0, 0])
        ty = float(tvec[1, 0])
        tz = float(tvec[2, 0])

        err_x = abs(tx - row["x_position"])
        err_y = abs(ty - row["z_position"])
        err_z = abs(tz - row["y_position"])

        err_3d = math.sqrt(err_x**2 + err_y**2 + err_z**2)
        errors_3d.append(err_3d)
        errors_x.append(err_x)
        errors_y.append(err_y)
        errors_z.append(err_z)

    if not errors_3d:
        return float("inf"), float("inf"), float("inf"), float("inf")

    mean_3d = float(np.mean(errors_3d))
    mean_x = float(np.mean(errors_x))
    mean_y = float(np.mean(errors_y))
    mean_z = float(np.mean(errors_z))
    return mean_3d, mean_x, mean_y, mean_z


def run_calibration_on_subset(cv2, board, subset_indices, candidate_views, image_size):
    """Roda cv2.calibrateCamera sobre um subconjunto especifico de views de calibracao."""
    import numpy as np

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
    iterations, outputs_base_dir, matrizes_dir, cv2, opencv_version
):
    import numpy as np

    video_name = os.path.basename(video_path)
    video_stem = os.path.splitext(video_name)[0]

    # Criar subpasta com sufixo 'opt'
    video_out_dir = os.path.join(outputs_base_dir, f"{video_stem}_opt")
    os.makedirs(video_out_dir, exist_ok=True)
    os.makedirs(matrizes_dir, exist_ok=True)

    console_log_path = os.path.join(video_out_dir, "console_output_opt.txt")
    logger = TeeLogger(console_log_path)
    orig_stdout = sys.stdout
    sys.stdout = logger

    try:
        print("\n" + "#" * 72)
        print("PROCESSANDO VÍDEO COM OTIMIZAÇÃO 3D PNP: %s" % video_name)
        print("#" * 72)
        print("Caminho do vídeo: %s" % video_path)
        print("Pasta de saída: %s" % video_out_dir)
        print("Dataset ROI ground-truth: %s (%d registros)" % (roi_csv_path, len(roi_rows)))

        detector = cv2.aruco.CharucoDetector(board)

        # 1) Abrir video
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("ERRO: nao foi possivel abrir o video: %s" % video_path)
            return False

        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print("Video: %dx%d, ~%d frames" % (w, h, total_frames))
        image_size = (w, h)

        # 2) Extrair TODAS as views validas do video
        candidate_views = []
        frame_idx = -1
        sampled = 0

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

            # Tentar extrair obj_points e img_points via matchImagePoints
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

        M = len(candidate_views)
        print("Frames amostrados: %d | views validas acumuladas: %d" % (sampled, M))

        if M < min_views:
            print("ERRO: views validas insuficientes (%d < min %d) para calibrar." % (M, min_views))
            return False

        # 3) Avaliar Calibracao Baseline (usando amostragem padrao das M views)
        baseline_indices = list(range(min(M, max_views)))
        baseline_res = run_calibration_on_subset(cv2, board, baseline_indices, candidate_views, image_size)

        if baseline_res is None:
            print("ERRO na calibracao baseline.")
            return False

        base_mean_3d, base_x, base_y, base_z = evaluate_pnp_3d_error(
            cv2, baseline_res["K"], baseline_res["dist"], roi_rows
        )
        print("\n--- RESULTADO BASELINE (Amostragem Padrao %d views) ---" % len(baseline_indices))
        print("RMS Reproj: %.4f px" % baseline_res["rms"])
        print("K Baseline: fx=%.2f, fy=%.2f, cx=%.2f, cy=%.2f"
              % (baseline_res["K"][0, 0], baseline_res["K"][1, 1], baseline_res["K"][0, 2], baseline_res["K"][1, 2]))
        print("Erro Medio 3D PnP: %.4f m (%.2f cm) [X: %.2f cm, Y: %.2f cm, Z: %.2f cm]"
              % (base_mean_3d, base_mean_3d * 100, base_x * 100, base_y * 100, base_z * 100))

        # 4) ALGORITMO DE OTIMIZACAO DE SUBCONJUNTO DE VIEWS
        print("\n" + "=" * 72)
        print("INICIANDO BUSCA DO SUBCONJUNTO OTIMIZADO DE FRAMES...")
        print("Teto de iteracoes: %d | faixa de views: [%d, %d]" % (iterations, min_views, min(M, max_views)))
        print("=" * 72)

        start_time = time.time()
        best_indices = list(baseline_indices)
        best_res = baseline_res
        best_err_3d = base_mean_3d
        best_err_xyz = (base_x, base_y, base_z)

        # Passo A: Busca Gulosa de Remocao (Backward Elimination) a partir de todas as views
        current_indices = list(range(M))
        print("\n[Passo 1/2] Iniciando Busca Gulosa de Remocao (Backward Elimination) a partir de %d views..." % M)
        
        curr_res = run_calibration_on_subset(cv2, board, current_indices, candidate_views, image_size)
        if curr_res is not None:
            curr_err_3d, curr_x, curr_y, curr_z = evaluate_pnp_3d_error(
                cv2, curr_res["K"], curr_res["dist"], roi_rows
            )
            if curr_err_3d < best_err_3d:
                best_err_3d = curr_err_3d
                best_indices = list(current_indices)
                best_res = curr_res
                best_err_xyz = (curr_x, curr_y, curr_z)
                print("  -> [GULOSO INICIAL] Todas as %d views: Erro 3D = %.4f m (%.2f cm) | RMS = %.4f px"
                      % (M, best_err_3d, best_err_3d * 100, best_res["rms"]))

        # Passe guloso de remocao item a item
        improved = True
        step_count = 0
        while improved and len(current_indices) > min_views:
            improved = False
            best_removal_idx = None
            total_cand = len(current_indices)
            print("  -> [GULOSO Rodada %d] Avaliando remocao de 1 view dentre %d views..." % (step_count + 1, total_cand))

            for c_idx, idx in enumerate(current_indices, 1):
                if c_idx % max(1, total_cand // 5) == 0 or c_idx == total_cand:
                    print("      ...avaliados %d/%d candidatos | Melhor Erro 3D ate agora: %.2f cm"
                          % (c_idx, total_cand, best_err_3d * 100))

                cand = [i for i in current_indices if i != idx]
                c_res = run_calibration_on_subset(cv2, board, cand, candidate_views, image_size)
                if c_res is None or c_res["rms"] > RMS_ACCEPTABLE:
                    continue
                err_3d, ex, ey, ez = evaluate_pnp_3d_error(cv2, c_res["K"], c_res["dist"], roi_rows)
                if err_3d < best_err_3d:
                    best_err_3d = err_3d
                    best_removal_idx = idx
                    best_indices = list(cand)
                    best_res = c_res
                    best_err_xyz = (ex, ey, ez)
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

        # Passo B: Busca Local Estocastica / Monte Carlo (Intercalando mutacoes no melhor subconjunto)
        max_k = min(M, max_views)
        tested_count = 0
        print("\n[Passo 2/2] Iniciando Busca Estocastica / Monte Carlo (%d iteracoes)..." % iterations)

        log_interval = max(1, iterations // 10)

        for it in range(1, iterations + 1):
            tested_count += 1
            # Estrategia 70% mutacao do melhor atual, 30% amostragem aleatoria nova
            if random.random() < 0.7 and len(best_indices) >= min_views:
                k = random.randint(min_views, max_k)
                cand_set = set(best_indices)
                # Mutar: remover 1 a 3 elementos e adicionar novos
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

            if len(cand_indices) < min_views:
                continue

            c_res = run_calibration_on_subset(cv2, board, cand_indices, candidate_views, image_size)
            if c_res is None or c_res["rms"] > RMS_ACCEPTABLE:
                continue

            err_3d, ex, ey, ez = evaluate_pnp_3d_error(cv2, c_res["K"], c_res["dist"], roi_rows)
            if err_3d < best_err_3d:
                best_err_3d = err_3d
                best_indices = list(cand_indices)
                best_res = c_res
                best_err_xyz = (ex, ey, ez)
                print("  -> [NOVO MELHOR %d/%d] Subconjunto de %d views | Novo Erro 3D: %.4f m (%.2f cm) | RMS: %.4f px"
                      % (it, iterations, len(best_indices), best_err_3d, best_err_3d * 100, best_res["rms"]))
            elif it % log_interval == 0:
                print("  -> [PROGRESSO %d/%d (%.0f%%)] Melhor Erro 3D ate agora: %.2f cm (%d views | RMS: %.4f px)"
                      % (it, iterations, (it / iterations) * 100, best_err_3d * 100, len(best_indices), best_res["rms"]))

        elapsed = time.time() - start_time
        print("\nBusca concluida em %.2f segundos (%d combinacoes testadas)." % (elapsed, tested_count))

        # Extrair variaveis da melhor calibracao encontrada
        K_opt = best_res["K"]
        dist_opt = best_res["dist"]
        rms_opt = best_res["rms"]
        num_views_opt = len(best_indices)
        fx, fy = float(K_opt[0, 0]), float(K_opt[1, 1])
        cx, cy = float(K_opt[0, 2]), float(K_opt[1, 2])
        opt_x, opt_y, opt_z = best_err_xyz

        # 5) IMPRIMIR RELATORIO COMPARATIVO
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

        # 6) SALVAR ARQUIVOS DE SAIDA COM SUFIXO 'opt'
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
            "calibration_method": "Optimization by PnP 3D Error Minization",
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

        # Formatacao para MATLAB (.m)
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
        description="Calibracao de camera por ChArUco OTIMIZADA por erro 3D de PnP."
    )
    parser.add_argument(
        "--video",
        default=None,
        help="Caminho de um video (.mp4) ou pasta com videos (default: codigoCalibracaoCamera/videos)",
    )
    parser.add_argument(
        "--roi-csv",
        default=default_roi_csv,
        help="Caminho do arquivo CSV de ROI (default: resultadosROI/resultados_ROI_otsu05_2007.csv)",
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
            opencv_version=opencv_version
        )
        if ok:
            successes += 1

    print("\n" + "=" * 72)
    print("CONCLUÍDO: %d de %d vídeo(s) processado(s) com sucesso." % (successes, len(video_files)))
    print("=" * 72)


if __name__ == "__main__":
    main()
