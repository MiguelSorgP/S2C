# S2C - Comunicação Screen-to-Camera Baseada em Tensores e Posicionamento 3D

Este repositório contém uma biblioteca completa de simulação, recepção, decodificação e estimativa de pose 3D para sistemas de **Comunicação por Câmera Óptica (OCC - Optical Camera Communications)** aplicados a displays, também conhecidos como **Comunicação Tela-Câmera (S2C - Screen-to-Camera)**. 

Os algoritmos implementados aqui são baseados na teoria matemática de decomposições tensoriais (PARAFAC/Mínimos Quadrados Alternados e Fatoração Khatri-Rao) descrita nos artigos científicos da pasta [informacoes].

---

## 📁 Estrutura do Repositório

```text
S2C/
│
├── gerarVideos.m                 # Transmissão: Modulação e geração de vídeos codificados (.avi)
├── loop_recepcao_Completo.m      # Recepção: Pipeline completo de processamento em lote dos vídeos
├── loop_IoU.m                    # Validação: Medição de acurácia (IoU) da detecção de ROI sob ruído
├── plotar_Figuras.m              # Interface (GUI): Visualizador de métricas e histogramas de ruído
│
├── dadosROI.m                    # Posicionamento: Extração de coordenadas de tela (ROI) de gravações
├── resolverPnP.m                 # Posicionamento: Solver do problema PnP (pose 3D da câmera)
├── analise_pnp.html              # Dashboard Web: Visualização interativa 3D/2D dos resultados do PnP
│
├── funcoes/                      # Pasta com algoritmos matemáticos e helpers do MATLAB
│   ├── OCC_Rx.m                  # Função receptora principal (seleciona e gerencia os decodificadores)
│   ├── KRF_OCC.m                 # Receptor não-iterativo OCC-KRF (baseado em SVD pixel a pixel)
│   ├── ALS_OCC.m                 # Receptor iterativo semi-cego OCC-ALS (Alternating Least Squares)
│   ├── automaticROI_v2.m         # Algoritmo de detecção automática da tela (ROI) por variação temporal
│   ├── correctPerspective.m      # Retificação geométrica de perspectiva usando homografia projetiva
│   ├── selectFramesAutomatically.m # Sincronização temporal e alinhamento de fase de amostragem
│   └── ... (outras 25+ funções auxiliares de modulação/processamento)
│
├── informacoes/                  # Documentações científicas e teóricas de suporte
│   ├── S2C_Tensor_Explanation.md # Explicação teórica detalhada e mapeamento código-artigo
│   ├── Tensor-Based_Screen-to-Camera_Communications.md # Artigo (Letter 2023)
│   └── Integrated_data_detection_and_video_restoration_for_optical_camera_communications.md # Artigo (DSP 2023)
│
├── dadosBER/                     # Resultados salvos (.mat) de simulações com BER/desempenho
├── resultadosROI/                # Saída de rastreamento de ROI (resultados_ROI.csv)
├── resultadosPnP/                # Saída do solver de pose (resultados_PnP.csv)
└── videosUsados15_06/            # Vídeos originais e arquivos de metadados de transmissão (.mat)
```

---

## ⚡ 1. Comunicação (Modulação, Transmissão e Recuperação de Dados)

### 🎥 [gerarVideos.m]
* **Descrição**: Gera os vídeos codificados no formato `.avi` simulando a codificação espaço-temporal e o borramento do canal óptico.
* **Como usar**: Defina os parâmetros de execução (mensagem aleatória/definida, dimensões, protocolo OCC e nível de borramento) no início do arquivo e execute o script.

### 🖥️ [loop_recepcao_Completo.m]
* **Descrição**: Decodifica múltiplos vídeos em lote, suportando análises com/sem ruído, múltiplos algoritmos (OCC-KRF/ALS) e aceleração por GPU/CPU.
* **Como usar**: Configure a variável `videoDir` para a pasta das gravações, defina o algoritmo desejado em `rxAlgorithm` e execute o script, respondendo às perguntas de configuração no console.

### 📊 [loop_IoU.m]
* **Descrição**: Avalia a precisão (métrica IoU) do método de detecção automática de tela (ROI) sob ruído AWGN através de simulações de Monte Carlo.
* **Como usar**: Ajuste o diretório dos vídeos (`videoDir`), o vetor de SNR (`OnePnDB_base`), o número de iterações (`MC`) e execute o script.

### 📈 [plotar_Figuras.m]
* **Descrição**: Interface gráfica (GUI) para visualização e comparação das figuras de desempenho e métricas resultantes (como BER e histogramas).
* **Como usar**: Execute o script e selecione a pasta contendo os arquivos `.mat` gerados nas simulações (geralmente localizados em `dadosBER/`).

---

## 📍 2. Posicionamento (Pose e Rastreamento da Câmera)

O repositório inclui uma pipeline para converter o rastreamento de tela em coordenadas 3D de translação e rotação da câmera (problema Perspective-n-Point - PnP).

### 🔍 [dadosROI.m]
* **Descrição**: Rastreia e extrai as coordenadas de pixels da tela (ROI) de todos os vídeos de gravações em lote.
* **Como usar**: Configure a variável `videoDir` para a pasta com as gravações e execute o script. O arquivo `resultados_ROI.csv` será gerado na pasta `resultadosROI/`.

### 📐 [resolverPnP.m]
* **Descrição**: Resolve o problema PnP para estimar a pose 3D da câmera a partir das coordenadas 2D da ROI, aplicando a calibração de lente.
* **Como usar**: Execute o script e selecione interativamente o arquivo CSV com os dados da ROI (`resultados_ROI.csv`). O resultado será salvo em `resultadosPnP/resultados_PnP.csv`.

### 🌐 [analise_pnp.html]
* **Descrição**: Dashboard interativo em HTML para visualização 3D/2D de trajetórias estimadas, estatísticas de erros e aplicação de correções.
* **Como usar**: Abra o arquivo `analise_pnp.html` em qualquer navegador web e carregue o arquivo de saída gerado pelo PnP (`resultados_PnP.csv`).

---

## 🧠 3. Fundamentos Teóricos e Algoritmos

Os sistemas S2C baseiam-se em modelar o vídeo capturado $\mathcal{Y}$ como um tensor PARAFAC de 3ª ordem:
$$\mathcal{Y} \triangleq [\![ \mathbf{H}, \mathbf{X}, \mathbf{S}; JL ]\!]$$

Onde os fatores estimados são:
* $\mathbf{H}$: Matriz de degradação do canal (borramento de lente e movimento).
* $\mathbf{X}$: Matriz de quadros do vídeo original não-degradado.
* $\mathbf{S}$: Matriz de símbolos contendo a mensagem codificada.

### Comparativo dos Algoritmos Receptores

| Característica | OCC-KRF ([KRF_OCC.m]) | OCC-ALS ([ALS_OCC.m]) |
| :--- | :--- | :--- |
| **Tipo de Processamento** | Não-iterativo (Direto) | Iterativo (Alternating Least Squares) |
| **Abordagem de Canal** | Requer estimativa/compensação prévia de $\mathbf{H}$ | Semi-cega (estima $\mathbf{H}, \mathbf{X}, \mathbf{S}$ conjuntamente) |
| **Velocidade** | Em frações de segundo (Não-iterativo) | Mais lenta (Requer dezenas de iterações) |
| **Confiabilidade Matemática** | SVD local rank-1 pixel a pixel | Otimização global de mínimos quadrados alternados |
| **Robustez a Ruído** | Sensível a erros residuais de calibração espacial | Alta robustez sob baixas SNRs de canal |

### Resolução de Ambiguidades de PARAFAC
Devido às ambiguidades intrínsecas de escala e permutação em tensores PARAFAC, o sistema emprega **Pilotos Físicos** no transmissor:
* **Ambiguidade de Permutação**: O transmissor insere nos dois primeiros símbolos da transmissão um vetor constante de `1`s e uma rampa estritamente crescente. O receptor calcula a razão entre as duas primeiras linhas estimadas e reordena os pixels de forma estritamente decrescente para restaurar a ordem espacial nativa.
* **Ambiguidade de Escala**: A escala é fixada exigindo que a primeira linha de símbolos $\mathbf{S}$ e o primeiro frame do vídeo $\mathbf{X}$ sejam inteiramente compostos por valores unitários (`1`), atuando como referência absoluta de ganho.

---

## 🛠️ Requisitos de Execução

* **Software Requerido**: MATLAB R2021a ou superior.
* **Toolboxes Recomendadas**:
  - *Parallel Computing Toolbox* (para aceleração de loops paralelos Monte Carlo).
  - *Image Processing Toolbox* / *Computer Vision Toolbox* (para manipulação de vídeo, retificação de imagem e solvers adicionais de PnP).
* **Hardware Recomendado**: GPU dedicada compatível com CUDA para ativação nativa do modo ultra-rápido de decodificação no `loop_recepcao_Completo.m`.

---
