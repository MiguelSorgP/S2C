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
* **Descrição**: Simula o transmissor codificando uma mensagem digital binária e quadros de um vídeo nativo em uma sequência temporal-espacial estruturada como um produto de Khatri-Rao ($\mathbf{S} \diamond \mathbf{X}$). Converte esse sinal em um vídeo sem compressão (`Uncompressed AVI`) para evitar distorções espaciais e aplica simulações de borramento óptico (defocus/canal).
* **Parâmetros Configuráveis**:
  - `mensagemAleatoria`: `1` (bits aleatórios) ou `0` (mensagem predefinida via `SOCC_messageDefined.m`).
  - `videoorigin`: `1` (usa um vídeo real como fundo, ex: `shuttle.avi`) ou `0` (sintético em escala de cinza).
  - `F`: Número de quadros do bloco original.
  - `Mmax` e `Nmax`: Dimensões da tela do display.
  - `M`, `N`, `S`, `P`: Parâmetros de bloco espacial e amostragem temporal ($K = S \cdot P$).
  - `prot`: Protocolo de recebimento previsto (`1` = OCC-KRF, `2` = OCC-ALS, `3` = Híbrido).
  - `simValor`: Nível de desfocagem/borramento artificial do canal (`1` a `6`).
  - `fps`: Taxa de quadros do vídeo gerado (tipicamente `30` FPS).

### 🖥️ [loop_recepcao_Completo.m]
* **Descrição**: O script receptor principal de processamento em lote. Ele lê os vídeos de gravações de câmera, detecta a tela, extrai as métricas de recepção, reconstrói o vídeo transmitido e decodifica a mensagem original.
* **Principais Recursos e Atualizações**:
  - **Suporte a Múltiplos Algoritmos**: Escolha entre o receptor não-iterativo ultra-rápido **OCC-KRF** (`rxAlgorithm = 1`) e o receptor iterativo robusto **OCC-ALS** (`rxAlgorithm = 2`).
  - **Aceleração por GPU Nativa**: Detecta e ativa automaticamente a computação por GPU (usando operações vetorizadas tridimensionais de matrizes de páginas como `pagesvd` e `pagemtimes`) para simulações Monte Carlo de ruído AWGN com 1000+ iterações em paralelo. Caso não haja GPU compatível, executa um fallback transparente usando `parfor` na CPU.
  - **Interatividade no Console**: 
    1. Pergunta se deseja prosseguir a partir de um checkpoint salvo (evita retrabalho caso a execução seja interrompida).
    2. Pergunta se deseja carregar as coordenadas de ROI a partir de um CSV pré-existente (ex: `resultados_ROI.csv`).
    3. Pergunta se deseja filtrar e selecionar vídeos interativamente através de uma GUI customizada (`selecionarVideosGUI.m`).
  - **Tratamento Avançado de ROI**: Detecção automática por variância temporal (`roiFlag = 1`), seleção manual (`roiFlag = 3`) ou retificação geométrica de perspectiva (`correcaoPerspectiva = true`) via homografia projetiva de 4 cantos.
  - **Condição de Parada Inteligente**: Durante varreduras de Monte Carlo com ruído AWGN, o laço de simulação é otimizado para interromper a execução quando o BER chega a zero ou atinge o valor obtido na decodificação "limpa" (sem ruído), preenchendo as SNRs subsequentes automaticamente e reduzindo drasticamente o tempo de processamento.
  - **Configurações Adicionais**: Salvamento opcional das imagens de ROI extraídas para auditoria (`salvarImagensROI = true`).

### 📊 [loop_IoU.m]
* **Descrição**: Script focado em validar numericamente o algoritmo de detecção automática de tela ([automaticROI_v2.m]). Executa testes de Monte Carlo adicionando ruído AWGN aos quadros do vídeo e calcula a métrica de Interseção sobre União (IoU) em relação às coordenadas de referência da tela em diferentes níveis de SNR.

### 📈 [plotar_Figuras.m]
* **Descrição**: Uma interface gráfica interativa (GUI) desenvolvida para carregar e comparar os resultados salvos na pasta `dadosBER/`. Permite visualizar curvas de taxa de erro de bit (BER) versus SNR ($1/P_n$ dB) e analisar histogramas de ruído experimental.

---

## 📍 2. Posicionamento (Pose e Rastreamento da Câmera)

O repositório inclui uma pipeline para converter o rastreamento de tela em coordenadas 3D de translação e rotação da câmera (problema Perspective-n-Point - PnP).

### 🔍 [dadosROI.m]
* **Descrição**: Processa em lote os vídeos gravados (`.mp4`), detecta os 4 cantos da tela (ROI) ao longo do tempo e mapeia as posições físicas esperadas de distância vertical (eixo Y) e deslocamento lateral (eixo X).
* **Saída**: Exporta as coordenadas de pixel dos quatro cantos e metadados de distância para `resultadosROI/resultados_ROI.csv`. Oferece modo interativo de verificação visual quadro a quadro.

### 📐 [resolverPnP.m]
* **Descrição**: Carrega o arquivo `resultados_ROI.csv`, aplica o modelo de calibração intrínseca e de distorção radial/tangencial da lente da câmera, e resolve as equações geométricas do PnP.
* **Algoritmos**:
  1. Um solver analítico planar por Transformada Linear Direta (DLT) desenvolvido sob medida (roda de forma independente, sem necessidade de toolboxes do MATLAB).
  2. O solver de PnP nativo do MATLAB (`estimateWorldCameraPose` da Computer Vision Toolbox), caso instalado.
* **Saída**: Salva os vetores estimados de translação (coordenadas $X, Y, Z$ da câmera em metros) e rotação (ângulos de Roll, Pitch, Yaw) em `resultadosPnP/resultados_PnP.csv`.

### 🌐 [analise_pnp.html]
* **Descrição**: Um dashboard web interativo de alta fidelidade visual. Permite arrastar e soltar o CSV gerado (`resultados_PnP.csv`) para plotar gráficos 3D interativos da trajetória estimada da câmera, comparar com as posições físicas terrestres, calcular estatísticas detalhadas de erro e aplicar filtros de suavização de ruído de pose.

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
| **Velocidade** | Extremamente rápida (Frações de segundo) | Mais lenta (Pode requerer dezenas de iterações) |
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

## 🚀 Como Começar

1. **Gere o Vídeo Codificado**:
   Execute o script [gerarVideos.m] no MATLAB configurando `simValor = 1` e `mensagemAleatoria = 0`. O script salvará o vídeo codificado na pasta raiz e criará o arquivo `.mat` com os metadados.
   
2. **Execute a Recepção e Decodificação**:
   Abra o script [loop_recepcao_Completo.m], aponte a variável `videoDir` para a pasta de suas gravações de teste e execute-o. Responda às perguntas iniciais exibidas no console do MATLAB para controlar o pipeline.

3. **Gere os Dados de Posicionamento**:
   Rode o script [dadosROI.m] apontado para a mesma pasta de gravações para obter o CSV `resultados_ROI.csv`.

4. **Estime a Pose 3D**:
   Rode o script [resolverPnP.m], selecione o CSV criado no passo anterior e aguarde a geração do relatório `resultados_PnP.csv`.

5. **Visualize o Dashboard**:
   Abra o dashboard interativo [analise_pnp.html] em qualquer navegador moderno e arraste o arquivo `resultados_PnP.csv` na interface.
