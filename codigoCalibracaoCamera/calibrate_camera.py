#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Calibracao de camera por ChArUco (Mestrado - IPS Tela-Camera, Fase 1).

Processa VIDEO(S) de calibracao gravado(s) e devolve os intrinsecos (K, dist).
O tabuleiro foi gerado/impresso pelo passo anterior; a definicao (dicionario, geometria e
tamanhos MEDIDOS pos-impressao) e lida de codigoCalibracaoCamera/charuco_config.json.

ATENCAO sobre a validade do K:
  O video DEVE ter sido gravado no MESMO A54 dos dados, em 1280x720, modo video pro,
  foco 0,8, zoom 1x e estabilizacao OFF. O K resultante so vale para 1280x720 com esses
  ajustes travados. Mudou resolucao/zoom/foco -> recalibrar.

Requisitos:
  - Python 3
  - opencv-contrib-python >= 4.7  (API nova: cv2.aruco.CharucoDetector + board.matchImagePoints)
  - numpy

Uso:
  python codigoCalibracaoCamera/calibrate_camera.py
  python codigoCalibracaoCamera/calibrate_camera.py --video codigoCalibracaoCamera/videos/meu_video.mp4
  python codigoCalibracaoCamera/calibrate_camera.py --video codigoCalibracaoCamera/videos --every 15 --max-views 40
"""

import argparse
from datetime import datetime
import glob
import json
import os
import sys

# ---------------------------------------------------------------------------
# Limiares de verificacao (criterios de aceite).
# ---------------------------------------------------------------------------
MIN_CHARUCO_CORNERS = 12          # cantos minimos por frame para aceitar a view
VIEWS_PASS = 15                   # num_views: PASS se >=, senao WARN (critico)
RMS_PASS = 0.6                    # rms < 0.6 px -> PASS
RMS_ACCEPTABLE = 1.0              # rms < 1.0 px -> ACEITAVEL; >= 1.0 -> WARN (critico)
PRINCIPAL_TOL = 0.15              # cx/cy podem desviar ate 15% da metade do quadro
FOCAL_TOL = 0.03                  # fx/fy devem diferir < 3%
TILT_MIN_DEG = 15.0               # diversidade: WARN se nenhuma view inclinar mais que isso
NORMAL_CONCENTRATION_MAX = 0.95   # WARN se as normais do tabuleiro forem quase todas iguais


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
    """Exige OpenCV >= 4.7 com o modulo aruco; mensagens de erro claras."""
    try:
        import cv2
    except ImportError:
        sys.exit(
            "ERRO: nao foi possivel importar 'cv2'.\n"
            "Instale o pacote CONTRIB (que inclui o modulo aruco):\n"
            "    pip install \"opencv-contrib-python>=4.7\"\n"
            "Atencao: 'opencv-python' (sem -contrib) NAO traz cv2.aruco."
        )
    version = cv2.__version__
    try:
        major, minor = (int(x) for x in version.split(".")[:2])
    except ValueError:
        sys.exit("ERRO: nao consegui interpretar a versao do OpenCV: %r" % version)
    if (major, minor) < (4, 7):
        sys.exit(
            "ERRO: este script exige OpenCV >= 4.7 (API nova de cv2.aruco).\n"
            "Versao encontrada: %s\n"
            "Atualize: pip install -U \"opencv-contrib-python>=4.7\"" % version
        )
    if not hasattr(cv2, "aruco") or not hasattr(cv2.aruco, "CharucoDetector"):
        sys.exit(
            "ERRO: cv2.aruco.CharucoDetector ausente.\n"
            "Verifique se instalou 'opencv-contrib-python>=4.7' (e nao 'opencv-python')."
        )
    return cv2, version


def load_board(cv2, config):
    """Reconstroi o CharucoBoard a partir do config (tamanhos MEDIDOS)."""
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


def banner(text, ch="!"):
    line = ch * 72
    return "\n%s\n%s\n%s" % (line, text, line)


def process_single_video(video_path, config, board, dict_name, dict_id, squares_x, squares_y,
                         square_len, marker_len, every, max_views, outputs_base_dir, matrizes_dir, cv2, opencv_version):
    import numpy as np
    import traceback

    video_name = os.path.basename(video_path)
    video_stem = os.path.splitext(video_name)[0]

    video_out_dir = os.path.join(outputs_base_dir, video_stem)
    os.makedirs(video_out_dir, exist_ok=True)
    os.makedirs(matrizes_dir, exist_ok=True)

    console_log_path = os.path.join(video_out_dir, "console_output.txt")
    logger = TeeLogger(console_log_path)
    orig_stdout = sys.stdout
    sys.stdout = logger

    try:
        print("\n" + "#" * 72)
        print("PROCESSANDO VÍDEO: %s" % video_name)
        print("#" * 72)
        print("Caminho do vídeo: %s" % video_path)
        print("Pasta de saída: %s" % video_out_dir)

        if not config.get("_measured_after_print", False):
            print(banner(
                "AVISO: charuco_config.json indica _measured_after_print=false.\n"
                "Voce esta usando os tamanhos NOMINAIS, nao os MEDIDOS pos-impressao.\n"
                "A escala do K (fx, fy) sai proporcional ao erro do tamanho do quadrado.\n"
                "Meca o quadrado impresso e atualize square_length_m/marker_length_m."
            ))

        print("Tabuleiro: %s (id=%d), %dx%d, square=%.4f m, marker=%.4f m"
              % (dict_name, dict_id, squares_x, squares_y, square_len, marker_len))

        detector = cv2.aruco.CharucoDetector(board)

        # 1) Abrir o video e checar resolucao
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("ERRO: nao consegui abrir o video: %s" % video_path)
            return False

        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print("Video: %dx%d, ~%d frames" % (w, h, total))

        if (w, h) != (1280, 720):
            print(banner(
                "RESOLUCAO INESPERADA: %dx%d (esperado 1280x720).\n"
                "O K so vale para a resolucao/zoom/foco em que o video foi gravado.\n"
                "Se este nao for o setup dos dados, PARE e regrave em 1280x720." % (w, h)
            ))

        # 2) Amostrar frames, detectar charuco, acumular views
        all_corners = []
        all_ids = []
        all_corner_xy = []
        sample_frame = None
        frame_idx = -1
        sampled = 0

        while len(all_corners) < max_views:
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

            all_corners.append(ch_corners)
            all_ids.append(ch_ids)
            all_corner_xy.append(ch_corners.reshape(-1, 2))
            if sample_frame is None:
                sample_frame = frame.copy()

        cap.release()

        num_views = len(all_corners)
        print("Frames amostrados: %d | views aceitas (>= %d cantos): %d"
              % (sampled, MIN_CHARUCO_CORNERS, num_views))

        if num_views < 4:
            print("ERRO: views insuficientes (%d) para calibrar %s." % (num_views, video_name))
            return False

        image_size = (w, h)

        # 3) Calibrar
        if hasattr(board, "matchImagePoints"):
            obj_points = []
            img_points = []
            for c, i in zip(all_corners, all_ids):
                match_res = board.matchImagePoints(c, i)
                if match_res is not None and len(match_res) >= 2:
                    op, ip = match_res[0], match_res[1]
                else:
                    op, ip = None, None
                if op is None or len(op) < MIN_CHARUCO_CORNERS:
                    continue
                obj_points.append(op)
                img_points.append(ip)

            if len(obj_points) < 4:
                print("ERRO: views validas insuficientes (%d) apos matchImagePoints." % len(obj_points))
                return False

            rms, K, dist, rvecs, tvecs = cv2.calibrateCamera(
                obj_points, img_points, image_size, None, None
            )
            method = "matchImagePoints + calibrateCamera"
        else:
            rms, K, dist, rvecs, tvecs = cv2.aruco.calibrateCameraCharuco(
                all_corners, all_ids, board, image_size, None, None
            )
            method = "calibrateCameraCharuco (fallback)"

        dist = dist.reshape(-1)
        fx, fy = float(K[0, 0]), float(K[1, 1])
        cx, cy = float(K[0, 2]), float(K[1, 2])

        # 4) Verificacoes
        warnings = []

        def status(ok_pass, ok_accept=None):
            if ok_pass:
                return "PASS"
            if ok_accept:
                return "ACEITAVEL"
            return "WARN"

        print("\n" + "=" * 72)
        print("RESUMO DA CALIBRACAO  (metodo: %s)" % method)
        print("=" * 72)
        print("OpenCV: %s" % opencv_version)
        print("image_size: %dx%d" % (w, h))
        print("fx=%.2f  fy=%.2f  cx=%.2f  cy=%.2f" % (fx, fy, cx, cy))
        print("dist (k1,k2,p1,p2,k3): [%s]"
              % ", ".join("%.5f" % v for v in dist[:5]))

        # (a) num_views
        v_pass = num_views >= VIEWS_PASS
        print("\n[%s] num_views_used = %d   (PASS se >= %d)"
              % (status(v_pass), num_views, VIEWS_PASS))
        if not v_pass:
            warnings.append("poucas views (%d < %d)" % (num_views, VIEWS_PASS))

        # (b) rms
        r_pass = rms < RMS_PASS
        r_accept = rms < RMS_ACCEPTABLE
        print("[%s] rms_reprojection_error = %.4f px   (PASS<%.1f, ACEITAVEL<%.1f)"
              % (status(r_pass, r_accept), rms, RMS_PASS, RMS_ACCEPTABLE))
        if not r_accept:
            warnings.append("rms alto (%.3f px >= %.1f)" % (rms, RMS_ACCEPTABLE))

        # (c) ponto principal ~ centro
        cx_ref, cy_ref = w / 2.0, h / 2.0
        cx_dev = abs(cx - cx_ref) / cx_ref
        cy_dev = abs(cy - cy_ref) / cy_ref
        pp_pass = cx_dev <= PRINCIPAL_TOL and cy_dev <= PRINCIPAL_TOL
        print("[%s] ponto principal: cx desvio=%.1f%%, cy desvio=%.1f%%  (tol +-%.0f%%)"
              % (status(pp_pass), cx_dev * 100, cy_dev * 100, PRINCIPAL_TOL * 100))
        if not pp_pass:
            warnings.append("ponto principal deslocado (cx %.0f%%, cy %.0f%%)"
                            % (cx_dev * 100, cy_dev * 100))

        # (d) fx ~ fy
        f_dev = abs(fx - fy) / max(fx, fy)
        f_pass = f_dev <= FOCAL_TOL
        print("[%s] fx vs fy: diferenca=%.2f%%  (tol %.0f%%)"
              % (status(f_pass), f_dev * 100, FOCAL_TOL * 100))
        if not f_pass:
            warnings.append("fx/fy divergentes (%.1f%%)" % (f_dev * 100))

        # (e) cobertura espacial 3x3
        grid = np.zeros((3, 3), dtype=int)
        for xy in all_corner_xy:
            for (px, py) in xy:
                gx = min(2, int(px / w * 3))
                gy = min(2, int(py / h * 3))
                grid[gy, gx] += 1
        filled = int((grid > 0).sum())
        border_cells = [(r, c) for r in range(3) for c in range(3) if (r, c) != (1, 1)]
        empty_border = [(r, c) for (r, c) in border_cells if grid[r, c] == 0]
        cov_pass = len(empty_border) == 0
        print("[%s] cobertura espacial 3x3: %d/9 celulas com cantos" % (status(cov_pass), filled))
        print("        grade (linhas=topo->base):")
        for r in range(3):
            print("        " + "  ".join("%5d" % grid[r, c] for c in range(3)))
        if not cov_pass:
            warnings.append("bordas/cantos sem cobertura (celulas vazias: %s)"
                            % ", ".join(str(c) for c in empty_border))

        # (f) diversidade de orientacao
        tilts = []
        normals = []
        for rv in rvecs:
            R, _ = cv2.Rodrigues(np.asarray(rv))
            n = R[:, 2].astype(float)
            if n[2] < 0:
                n = -n
            normals.append(n)
            nz = max(-1.0, min(1.0, abs(n[2])))
            tilts.append(np.degrees(np.arccos(nz)))
        tilts = np.asarray(tilts)
        tilt_max = float(tilts.max())
        concentration = float(np.linalg.norm(np.mean(normals, axis=0)))
        div_pass = tilt_max >= TILT_MIN_DEG and concentration <= NORMAL_CONCENTRATION_MAX
        print("[%s] diversidade de orientacao: inclinacao max=%.1f deg, "
              "concentracao das normais=%.2f (PASS: max>=%.0f e conc<=%.2f)"
              % (status(div_pass), tilt_max, concentration, TILT_MIN_DEG,
                 NORMAL_CONCENTRATION_MAX))
        if tilt_max < TILT_MIN_DEG:
            warnings.append(
                "views quase fronto-paralelas (incl. max=%.1f deg) - incline mais o tabuleiro"
                % tilt_max)
        elif concentration > NORMAL_CONCENTRATION_MAX:
            warnings.append(
                "inclinacoes pouco variadas (concentracao=%.2f) - incline o tabuleiro "
                "para lados diferentes (cima/baixo/esquerda/direita)" % concentration)

        # 5) Saidas de arquivos
        calib_path = os.path.join(video_out_dir, "camera_calib.json")
        undist_path = os.path.join(video_out_dir, "undistort_check.png")

        calib = {
            "video_source": video_name,
            "image_size": [w, h],
            "fx": fx, "fy": fy, "cx": cx, "cy": cy,
            "camera_matrix": K.tolist(),
            "dist_coeffs": dist[:5].tolist(),
            "dist_coeffs_labels": ["k1", "k2", "p1", "p2", "k3"],
            "rms_reprojection_error": float(rms),
            "num_views_used": num_views,
            "calibration_method": method,
            "opencv_version": opencv_version,
            "coverage_grid_3x3": grid.tolist(),
            "tilt_max_deg": tilt_max,
            "normal_concentration": concentration,
            "_capture_note": (
                "K valido apenas para %dx720, mesmo zoom/foco/estabilizacao do video. "
                "Galaxy A54, modo video pro, foco 0.6, zoom 1x, estabilizacao OFF." % w
            ),
            "config_used": config,
        }

        with open(calib_path, "w", encoding="utf-8") as f:
            json.dump(calib, f, indent=2, ensure_ascii=False)

        if sample_frame is not None:
            undistorted = cv2.undistort(sample_frame, K, dist[:5])
            lbl = sample_frame.copy()
            cv2.putText(lbl, "ORIGINAL (distorcido)", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 2, cv2.LINE_AA)
            cv2.putText(undistorted, "UNDISTORT", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2, cv2.LINE_AA)
            side_by_side = np.hstack([lbl, undistorted])
            cv2.imwrite(undist_path, side_by_side)

        # Exportacao para matrizesCalibracao/ (apenas formato .m)
        matriz_m_path = os.path.join(matrizes_dir, "calibracao_%s.m" % video_stem)

        now_str = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        m_lines = [
            "% --- PARÂMETROS DE CALIBRAÇÃO ÓTIMOS (GERADO AUTOMATICAMENTE) ---",
            f"% Data de geração: {now_str}",
            f"% Arquivo de origem: {video_name}",
            f"% Erro Reprojeção RMS: {float(rms):.4f} px",
            f"% Views Utilizadas: {num_views}",
            "",
            "% Matriz Intrínseca da Câmera (K)",
            "K = [",
            f"    {K[0, 0]:14.6f}, {K[0, 1]:14.6f}, {K[0, 2]:14.6f};",
            f"    {K[1, 0]:14.6f}, {K[1, 1]:14.6f}, {K[1, 2]:14.6f};",
            f"    {K[2, 0]:14.6f}, {K[2, 1]:14.6f}, {K[2, 2]:14.6f}",
            "];",
            "",
            "% Coeficientes de Distorção da Lente [k1, k2, p1, p2, k3]",
            f"distCoeffs = [{dist[0]:.6f}, {dist[1]:.6f}, {dist[2]:.6f}, {dist[3]:.6f}, {dist[4]:.6f}];",
            ""
        ]
        with open(matriz_m_path, "w", encoding="utf-8") as f:
            f.write("\n".join(m_lines))

        print("\nSalvo em outputs: %s" % calib_path)
        if sample_frame is not None:
            print("Salvo em outputs: %s" % undist_path)
        print("Salvo em matrizesCalibracao (.m): %s" % matriz_m_path)

        print("\n" + "=" * 72)
        if not warnings:
            print("CALIBRACAO OK")
        else:
            print("REVISAR ANTES DE SAIR: " + "; ".join(warnings))
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

    here = os.path.dirname(os.path.abspath(__file__))   # <raiz>/codigoCalibracaoCamera
    root = os.path.dirname(here)                          # <raiz>
    default_videos_dir = os.path.join(here, "videos")
    outputs_base_dir = os.path.join(here, "outputs")
    matrizes_dir = os.path.join(root, "matrizesCalibracao")
    default_config = os.path.join(here, "charuco_config.json")

    parser = argparse.ArgumentParser(
        description="Calibracao de camera por ChArUco em lote a partir de video(s)."
    )
    parser.add_argument(
        "--video",
        default=None,
        help="Caminho de um video (.mp4) ou pasta com videos (default: codigoCalibracaoCamera/videos)",
    )
    parser.add_argument(
        "--config",
        default=default_config,
        help="Caminho do charuco_config.json (default: codigoCalibracaoCamera/charuco_config.json)",
    )
    parser.add_argument(
        "--every", type=int, default=15,
        help="Amostrar 1 a cada N frames (default: 15)",
    )
    parser.add_argument(
        "--max-views", type=int, default=40,
        help="Teto de frames validos a usar (default: 40)",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.config):
        sys.exit("ERRO: config nao encontrado: %s" % args.config)

    with open(args.config, encoding="utf-8") as f:
        config = json.load(f)

    board, dict_name, dict_id, squares_x, squares_y, square_len, marker_len = load_board(
        cv2, config
    )

    # Identificar lista de videos a processar
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

    print("Encontrado(s) %d video(s) para calibrar." % len(video_files))

    successes = 0
    for idx, v_path in enumerate(video_files, 1):
        print("\n[%d/%d] Processando: %s" % (idx, len(video_files), os.path.basename(v_path)))
        ok = process_single_video(
            video_path=v_path,
            config=config,
            board=board,
            dict_name=dict_name,
            dict_id=dict_id,
            squares_x=squares_x,
            squares_y=squares_y,
            square_len=square_len,
            marker_len=marker_len,
            every=args.every,
            max_views=args.max_views,
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
