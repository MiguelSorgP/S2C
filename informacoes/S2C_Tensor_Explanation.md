# Comunicações Screen-to-Camera (S2C) Baseadas em Tensores: Teoria e Código

Este documento apresenta uma análise detalhada e integrada que conecta a teoria matemática desenvolvida nos dois artigos científicos com a implementação prática nos scripts MATLAB `gerarVideos.m` e `loop_recepcao_Completo.m` (e suas funções auxiliares em `funcoes/`).

---

## 1. Visão Geral dos Artigos e Conceitos Chave

Os códigos baseiam-se em dois artigos principais:

1. **Artigo da Letter (2023):** *"Tensor-Based Screen-to-Camera Communications"* (IEEE Communications Letters).
   - **Foco:** Apresenta o modelo tensorial de terceira ordem para S2C com base na decomposição PARAFAC (Parallel Factor Analysis). Propõe o receptor iterativo semi-cego **OCC-ALS** (Alternating Least Squares) para estimar conjuntamente a degradação da imagem ($H$), a detecção de símbolos ($S$) e a restauração do vídeo ($X$). Deriva as condições de identificabilidade e unicidade.
2. **Artigo do Journal (2023):** *"Integrated data detection and video restoration for optical camera communications"* (Digital Signal Processing).
   - **Foco:** Apresenta a codificação espacial-temporal baseada no produto de Khatri-Rao (KRST). Propõe o receptor não-iterativo cego **OCC-KRF** (OCC Khatri-Rao Factorization) que separa os fatores de símbolos e do vídeo por meio da Decomposição em Valores Singulares (SVD) de matrizes rank-1 pixel a pixel, sob a hipótese de que a matriz de degradação espacial $H$ seja conhecida ou compensada a priori.

### O Modelo Matemático Tensorial

Ambos os artigos modelam o sinal de vídeo recebido $\mathcal{Y}$ como um tensor de terceira ordem de dimensões $(MN \times F \times K)$, cujas dimensões representam:
- **Modo 1 ($MN$):** Domínio Espacial (resolução espacial do Sensor de Imagem/câmera).
- **Modo 2 ($F$):** Domínio Temporal do Vídeo (número de quadros do bloco de vídeo original).
- **Modo 3 ($K$):** Domínio Temporal da Codificação (número de subquadros/pulsos por símbolo, $K = S_{bits} \cdot P_{pulsos}$).

Matematicamente, o tensor livre de ruído é dado pelo modelo PARAFAC:
$$\mathcal{Y} \triangleq [\![ \mathbf{H}, \mathbf{X}, \mathbf{S}; JL ]\!]$$
onde os três fatores do tensor são:
- $\mathbf{H} \in \mathbb{R}^{MN \times JL}$: Matriz de degradação da imagem (borramento ótico e de movimento combinados com o ganho DC do canal óptico).
- $\mathbf{X} \in \mathbb{R}^{F \times JL}$: Matriz do vídeo original (undegraded) de resolução original $J \times L$ pixels ($JL$ é o rank de PARAFAC).
- $\mathbf{S} \in \mathbb{R}^{K \times JL}$: Matriz de símbolos de informação codificados.

Os desdobramentos (unfoldings) matriciais do tensor são representados por:
- **Modo 1:** $\mathbf{Y}_{(1)} = (\mathbf{S} \diamond \mathbf{X}) \mathbf{H}^T \in \mathbb{R}^{FK \times MN}$
- **Modo 2:** $\mathbf{Y}_{(2)} = (\mathbf{H} \diamond \mathbf{S}) \mathbf{X}^T \in \mathbb{R}^{KMN \times F}$
- **Modo 3:** $\mathbf{Y}_{(3)} = (\mathbf{X} \diamond \mathbf{H}) \mathbf{S}^T \in \mathbb{R}^{MNF \times K}$

onde $\diamond$ denota o produto de Khatri-Rao (produto de Kronecker coluna a coluna).

---

## 2. Resolução Prática de Ambiguidades (Conexão Teoria-Código)

A decomposição PARAFAC é unicamente identificável sob certas condições (Proposições 2 e 3 do Journal/Letter), mas possui duas ambiguidades inerentes: **permutação** das colunas ($\mathbf{\Pi}$) e **escala** ($\mathbf{\Delta}$). O código resolve essas ambiguidades de forma engenhosa usando pilotos físicos:

### A. Ambiguidade de Permutação ($\mathbf{\Pi}$)
Para garantir que as colunas dos fatores estimados correspondam às posições corretas dos pixels físicos da tela sem sofrerem permutações aleatórias, utiliza-se a técnica descrita na **Proposição 3** da Letter.
No transmissor (`SOCC_message.m:L19-21`), os dois primeiros símbolos da matriz de transmissão $\mathbf{S}$ são configurados como pilotos conhecidos:
- A primeira linha é preenchida por uns: `S(1,:) = ones(1, M*N);`
- A segunda linha possui uma rampa linear crescente: `S(2,:) = 1/(M*N):1/(M*N):1;`

No receptor (`OCC_SRRsemRuido.m:L136-146`), a razão ponto a ponto entre a primeira e a segunda linha da matriz estimada $\mathbf{B}$ é calculada. Como a rampa original era crescente, a razão original $\mathbf{S}(1,:) ./ \mathbf{S}(2,:)$ é estritamente decrescente. Ao ordenar a razão estimada em ordem decrescente (`sort(..., 'descend')`), recupera-se o vetor de índices de permutação original `I` para reordenar as colunas das matrizes estimadas:
```matlab
[~,I] = sort(B(1,:)./B(2,:),'descend');
perm = eye(M*N);
perm(:,:) = perm(:,I);
Bmod = B * deltaB * perm;
```

### B. Ambiguidade de Escala ($\mathbf{\Delta}$)
Conforme a **Proposição 4** da Letter, a ambiguidade de escala é resolvida ao tornar conhecida uma linha da matriz de símbolos $\mathbf{S}$ e uma linha da matriz do vídeo $\mathbf{X}$.
1. **Símbolos:** A primeira linha de $\mathbf{S}$ é preenchida com uns. No receptor, elimina-se a escala de $\mathbf{S}$ dividindo a estimativa pela sua primeira linha: `Bmod = B ./ B(1, :);` (em `OCC_Rx.m`).
2. **Vídeo:** O primeiro frame do vídeo $\mathbf{X}$ é definido como uma tela branca de referência (todos os valores iguais a 1). Isso é garantido na função de extração de blocos do transmissor (`bloco_extraction.m:L9-11`):
   ```matlab
   if f == 1
       vgray(f, :) = ones(1, M*N);
   end
   ```
   No receptor, a ambiguidade de escala no vídeo é removida multiplicando o vídeo estimado pela razão do primeiro frame do vídeo original conhecido e o primeiro frame do vídeo estimado (`OCC_Rx.m`):
   ```matlab
   Cmod = (C.') .* (vgray(1, :) ./ C(:, 1).');
   ```

---

## 3. Explicação do Pipeline dos Scripts Principais

### A. Script `gerarVideos.m`

Este script simula a codificação e geração de um vídeo degradado pelo canal óptico.
1. **Parâmetros e Configuração:** Define o número de frames $F$ do bloco, a dimensão da tela $M_{max} \times N_{max}$ e subdivisões de bloco $M \times N$. Configura os parâmetros de modulação: número de símbolos por bloco $S$, número de pulsos/amostras por símbolo $P$, e o total de subquadros gerados $K = S \cdot P$.
2. **Modulação de Símbolos:** Invoca `SOCC_message.m` ou `SOCC_messageDefined.m`. Nelas, o bit 1 e o bit 0 são codificados usando funções como `BPPM.m` (Binary Pulse Position Modulation) onde os bits geram formas de onda específicas de $P$ amostras (ex: `S0 = [0.001; ones(P-1, 1)]` e `S1 = [ones(floor(P/2),1); 0.001; ones(ceil(P/2)-1,1)]`).
3. **Simulação de Canal:** Aplica degradações espaciais (borramento ótico/defocus) com base na variável `simValor`. Máscaras gaussianas ou de disco são criadas usando a função `fspecial('disk', R)` e a convolução espacial é aplicada por bloco.
4. **Construção do Vídeo Codificado:** Por meio da função `OCC_SRRsemRuido.m`, gera-se a representação temporal-espacial do produto de Khatri-Rao $\bar{\mathbf{X}} = \mathbf{S} \diamond \mathbf{X}$. Os blocos espaciais individuais são extraídos com `bloco_extraction.m` e as saídas são remontadas para compor o tensor degradado.
5. **Gravação:** O vídeo é salvo no formato AVI não compactado (`Uncompressed AVI`) para evitar que artefatos de compressão (como bloco DCT do H.264) degradem a informação de alta frequência espacial do sinal óptico.

---

### B. Script `loop_recepcao_Completo.m`

Este script executa o processamento do vídeo gravado pela câmera para extrair a informação.
1. **Importação dos Dados Originais:** Carrega os arquivos `.mat` gerados na transmissão para obter os parâmetros exatos do protocolo (símbolos de referência, matriz de modulação original para comparação de erro).
2. **Leitura e Extração de ROI:** O vídeo é lido quadro a quadro em escala de cinza (`readGrayscaleVideo.m`). Em seguida, extrai-se a ROI da tela usando coordenadas predefinidas em um CSV de resultados anterior (`usarCsvRoi = true`), detecção automática (`roiFlag = 3` usando `automaticROI_v2.m`), ou manualmente.
3. **Retificação Geométrica:** Se a câmera e a tela não estiverem em paralelo perfeito, ocorre distorção de perspectiva. A função `correctPerspective.m` aplica uma homografia projetiva com base nos 4 cantos da ROI detectada, mapeando-os de volta para um retângulo perfeito.
4. **Sincronização Temporal Fina por Alinhamento de Fase:** Como a câmera captura em uma taxa superior à exibição da tela (`fpsRx > fpsTx`), os frames são gravados em duplicidade. A função `selectFramesAutomatically.m` calcula a diferença absoluta entre quadros adjacentes para localizar o início e o fim da transmissão. Além disso, realiza um alinhamento de fase de transição para identificar exatamente a defasagem $p_{trans}$ dentro do padrão periódico de repetição.
5. **Remoção de Fundo e Normalização:** Opcionalmente, subtrai-se a imagem média de fundo silenciosa (`backgroundImage`) para eliminar reflexos estáticos no ambiente de gravação.
6. **Média de Quadros Repetidos (Downsampling):** Com base no fator de amostragem temporal `repeatedFrames`, a função `meanRepeatedFrames.m` integra consecutivamente blocos de frames para reduzir a dimensão temporal da captura de volta à dimensão nominal de $K \cdot F$.
7. **Algoritmo de Recepção Principal:** Invoca a função `OCC_Rx.m`, que agora suporta os dois algoritmos através da flag `rxAlgorithm`:
   - **OCC-KRF (`rxAlgorithm = 1`)**: Executa a fatoração de Khatri-Rao (`KRF_OCC.m`) pixel a pixel de forma não-iterativa e rápida.
   - **OCC-ALS (`rxAlgorithm = 2`)**: Executa a decomposição tensorial clássica de Mínimos Quadrados Alternados de forma iterativa e semi-cega (estimando conjuntamente os símbolos, o vídeo e a matriz de degradação do canal).
   Ambos os algoritmos eliminam as ambiguidades de permutação e escala nas estimativas finais.
8. **Decodificação de Mensagem e Metadados:** A função `decode_msg.m` recebe a matriz de símbolos de informação purificada $\mathbf{B}_{mod}$. Ela reconstrói os bits por meio da distância euclidiana mínima entre o sinal recebido e as formas de onda de referência `S0` (bit 1) e `S1` (bit 0). Em seguida, extrai a sequência de metadados integrada no transmissor:
   - **Cabeçalho:** 9 bits contínuos de valor 1.
   - **ID do transmissor:** 3 bits (`0 0 1`).
   - **Dimensão Vertical original:** 12 bits decimais.
   - **Dimensão Horizontal original:** 12 bits decimais.
9. **Simulação Avançada com Ruído e Monte Carlo:** Se `noiseFlag == 1`, executa-se uma varredura de relação sinal-ruído (SNR) simulando canal AWGN sobre as matrizes reais capturadas. Se o MATLAB suportar GPU, o código usa a vetorização 3D nativa com a função `pagesvd` em `KRF_OCC.m` para rodar 1000 iterações Monte Carlo em paralelo de forma ultra-rápida. Caso contrário, utiliza loops paralelos na CPU via `parfor`.

---

## 4. Explicação das Funções Auxiliares Críticas

### A. Algoritmo LSKRF em `KRF_OCC.m` (Método do Artigo do Journal)
A Fatoração de Khatri-Rao por Mínimos Quadrados (LSKRF) baseia-se em resolver a relação bilinear individualmente para cada pixel $m \in \{1, \dots, MN\}$.
Sob o modelo linear, a estimativa do produto de Khatri-Rao após a remoção do efeito de canal $H$ é dada por:
$$\hat{\mathbf{Z}} = \mathbf{Y}_{(1)} (\mathbf{H}^T)^{\dagger} \approx \mathbf{S} \diamond \mathbf{X}$$
onde $\hat{\mathbf{Z}} \in \mathbb{R}^{FK \times MN}$. Para cada coluna $m$ (pixel $m$), tem-se um vetor de tamanho $KF \times 1$:
$$\hat{\mathbf{z}}_m \approx \mathbf{s}_m \otimes \mathbf{x}_m$$
Ao reorganizar os $KF$ elementos desse vetor em uma matriz $\hat{\mathbf{Z}}_m$ de tamanho $K \times F$ (através do operador de descompactação), obtém-se uma matriz de rank-1 ideal:
$$\hat{\mathbf{Z}}_m \approx \mathbf{s}_m \mathbf{x}_m^T$$
A função `KRF_OCC` executa a Decomposição em Valores Singulares (SVD) dessa matriz:
$$\hat{\mathbf{Z}}_m = \mathbf{U} \mathbf{D} \mathbf{V}^T$$
A melhor aproximação rank-1 em Mínimos Quadrados, pelo teorema de Eckart-Young-Mirsky, é obtida a partir do maior valor singular $\sigma_1$ e seus respectivos vetores singulares esquerdo $\mathbf{u}_1$ e direito $\mathbf{v}_1$:
$$\hat{\mathbf{s}}_m = \sqrt{\sigma_1} \cdot \mathbf{u}_1 \quad \text{e} \quad \hat{\mathbf{x}}_m = \sqrt{\sigma_1} \cdot \mathbf{v}_1^*$$
Isso é codificado diretamente em `KRF_OCC.m:L58-59`:
```matlab
[U,Xi,V] = svd(Yunv);
A1(m,:) = sqrt(Xi(1,1))*(U(:,1).');
A2(:,m) = (V(:,1)')*sqrt(Xi(1,1));
```
Esse processo é repetido para todos os pixels, gerando as matrizes de estimativas brutas de símbolos e do vídeo sem necessidade de iterações, garantindo altíssima velocidade.

### B. Algoritmo Iterativo ALS em `OCC_Rx.m` / `ALS_OCC.m` (Método do Artigo da Letter)
Diferente do KRF, o ALS é um processo iterativo clássico para obter a decomposição PARAFAC global por otimização de mínimos quadrados alternados.
Em cada iteração, minimiza-se a diferença quadrática para um fator mantendo os outros dois fixos. As updates em mínimos quadrados ordinários são dadas por:
1. **Símbolos $\mathbf{S}$ (usando unfolding modo 2):**
   $$\hat{\mathbf{S}}^T = (\hat{\mathbf{H}} \diamond \hat{\mathbf{X}})^{\dagger} \mathbf{Y}_{(2)}^T$$
2. **Degradação $\mathbf{H}$ (usando unfolding modo 1):**
   $$\hat{\mathbf{H}}^T = (\hat{\mathbf{S}} \diamond \hat{\mathbf{X}})^{\dagger} \mathbf{Y}_{(1)}^T$$
3. **Vídeo $\mathbf{X}$ (usando unfolding modo 3):**
   $$\hat{\mathbf{X}}^T = (\hat{\mathbf{S}} \diamond \hat{\mathbf{H}})^{\dagger} \mathbf{Y}_{(3)}^T$$

Na recepção real implementada em `OCC_Rx.m`, o receptor **não conhece** o vídeo transmitido $\mathbf{X}$ e, portanto, executa a estimativa conjunta completa e semi-cega atualizando iterativamente os três fatores: a degradação (`Achap`), os símbolos (`Bchap`) e o vídeo (`Cchap`), resolvendo também as ambiguidades de escala e reordenação (permutação) de colunas.

Para otimizar o processamento paralelo com Monte Carlo (AWGN) usando aceleração por GPU, o laço de iterações do ALS foi totalmente vetorizado no plano tridimensional `[dim, dim, MC]` utilizando as funções nativas de matrizes de páginas do MATLAB (`pagemtimes` e `pagemldivide`), permitindo computar todas as realizações Monte Carlo simultaneamente em hardware gráfico com alto desempenho. Um laço sequencial em CPU atua como fallback caso a máquina não possua tais recursos gráficos ou suporte do MATLAB.

---

## 5. Mapeamento de Parâmetros: Teoria vs. Código

| Conceito Teórico / Variável nos Artigos | Variável no Código MATLAB | Significado e Função no Sistema |
| :--- | :--- | :--- |
| **$F$** | `F` | Número de frames do bloco de vídeo original (dimensão temporal nativa). |
| **$J \times L$** | `M` e `N` (para o bloco) | Dimensões espaciais (resolução em pixels) de cada bloco de vídeo transmitido na tela. |
| **$JL$ (Rank do Tensor)** | `M * N` | Número total de subcanais espaciais (pixels) por bloco. Define o rank do tensor. |
| **$S$ (Número de Símbolos)** | `S` | Número de bits transmitidos por pixel em cada bloco de vídeo. |
| **$P$ (Pulsos)** | `P` | Fator de sobreamostragem (pulsos por bit) para modulações baseadas em pulso (ex: PPM). |
| **$K = S \cdot P$** | `K` | Dimensão temporal da codificação (número total de subquadros por bloco). |
| **$\mathbf{X}$** | `vgray` / `Cchap` / `Cmod` | Matriz de vídeo original (dimensões $F \times JL$ no transmissor, estimada como $JL \times F$). |
| **$\mathbf{S}$** | `Sm` / `Bchap` / `Bmod` | Matriz de símbolos de transmissão codificados (dimensões $K \times JL$). |
| **$\mathbf{H}$** | `H` / `Achap` / `Amod` / `Ha` | Matriz de degradação da imagem/canal (dimensões $MN \times JL$). |
| **$\mathcal{Y}$** | `Aux` (3D desdobrada) / `Aux2` | Tensor ou matriz desdobrada de quadros de vídeo degradados recebidos. |
| **$\mathbf{\Pi}$** | `perm` / `I` | Matriz e índices de permutação para corrigir a ordenação espacial dos pixels. |
| **$\mathbf{\Delta}_X, \mathbf{\Delta}_S$** | `deltaC` / `deltaB` | Matrizes diagonais de escala para eliminar a ambiguidade de ganho/intensidade. |
| **$repeatedFrames$** | `repeatedFrames` | Número de vezes que cada frame codificado é repetido na gravação devido a $fps_{Rx} > fps_{Tx}$. |

---

## 6. Conclusões Práticas do Sistema

A análise dos códigos e dos artigos revela importantes trade-offs práticos:
- **Relação Fatores-Desempenho:**
  - O aumento de $P$ (amostras por símbolo) atua como um ganho de energia por bit (filtragem temporal/oversampling), reduzindo a taxa de erro (SER/BER) e melhorando a qualidade do vídeo reconstruído, mas exige câmeras com taxas de quadro ($fps_{Rx}$) significativamente maiores.
  - O aumento de $F$ (quadros do vídeo) aumenta a diversidade temporal, garantindo maior imunidade ao ruído e facilitando a fatoração do tensor PARAFAC, mas reduz a taxa efetiva de bits transmitidos por segundo (throughput), além de aumentar a latência.
- **KRF vs. ALS:**
  - O **OCC-ALS** (`ALS_OCC`) é iterativo, mais lento e requer maior capacidade computacional, mas é robusto a estimativas incorretas de $H$ e permite estimar o canal cegamente.
  - O **OCC-KRF** (`KRF_OCC`) é direto (não-iterativo), incrivelmente rápido e viável para decodificação em tempo real, porém exige que o canal $H$ seja perfeitamente conhecido ou que a degradação geométrica/espacial seja previamente corrigida (como feito na recepção via `correctPerspective` e no alinhamento espacial de pixels).
