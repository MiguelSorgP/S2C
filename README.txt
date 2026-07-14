================================================================================
TUTORIAL DE USO DOS CÓDIGOS DA PASTA
================================================================================

Este documento apresenta uma breve descrição e instruções de uso dos códigos 
contidos neste diretório, divididos entre as áreas de Comunicação e Posicionamento.

--------------------------------------------------------------------------------
1. COMUNICAÇÃO
--------------------------------------------------------------------------------

* gerarVideos.m
  - Descrição: Código em MATLAB utilizado para gerar os vídeos codificados no formato .avi.
  - Como usar: Defina os parâmetros de execução (como mensagem aleatória ou definida, 
    número de quadros, dimensões da tela, e o protocolo OCC desejado) e execute o script.

* loop_recepcao_Completo.m
  - Descrição: Script MATLAB para decodificar múltiplos vídeos em lote, suportando 
    análises com ou sem ruído.
  - Como usar: Abra o arquivo e aponte a variável 'videoDir' para a pasta contendo 
    os vídeos a serem decodificados. Se necessário, ajuste as flags de seleção da 
    ROI (roiFlag) e os parâmetros de ruído adicionado (AWGN).

* loop_IoU.m
  - Descrição: Script utilizado para avaliar a acurácia e o comportamento do método 
    de detecção automática da ROI sob a influência de diferentes níveis de ruído (AWGN).
  - Como usar: Ajuste as flags de teste e o vetor de relação sinal-ruído ('OnePnDB_base'). 
    O script executa simulações de Monte Carlo para calcular a métrica de Interseção 
    sobre União (IoU) comparando com coordenadas de referência.

* plotar_Figuras.m
  - Descrição: Interface gráfica (GUI) desenvolvida para facilitar a visualização 
    e comparação das figuras e métricas resultantes (como BER e histogramas de ruído).
  - Como usar: Ao executar o script, uma janela de seleção será aberta. Selecione a 
    pasta contendo os arquivos '.mat' das simulações (geralmente localizados em 'dadosBER') 
    para gerar os gráficos comparativos.

--------------------------------------------------------------------------------
2. POSICIONAMENTO
--------------------------------------------------------------------------------

* dadosROI.m
  - Descrição: Extrai as coordenadas de localização da ROI de todos os vídeos MP4 em 
    um determinado diretório de gravações.
  - Como usar: Aponte a variável 'videoDir' para a pasta com as gravações originais. 
    Ao executar, o script realiza o rastreamento e exporta as coordenadas gerando 
    o arquivo 'resultados_ROI.csv' dentro da pasta 'resultadosROI/'.

* resolverPnP.m
  - Descrição: Resolve o problema de Perspective-n-Point (PnP) para estimar a pose 3D 
    da câmera a partir das coordenadas 2D da ROI.
  - Como usar: Execute o script e, na janela interativa, selecione o arquivo CSV 
    com os dados da ROI ('resultados_ROI.csv'). O script aplicará a calibração de 
    lente, calculará a pose 3D e salvará o resultado em 'resultadosPnP/resultados_PnP.csv'.

* analise_pnp.html
  - Descrição: Página/dashboard web interativo em HTML para visualizar, analisar e 
    aplicar correções nos resultados de posicionamento estimados pelo PnP.
  - Como usar: Abra o arquivo 'analise_pnp.html' diretamente em qualquer navegador 
    web. Na interface, carregue o arquivo de saída do PnP ('resultados_PnP.csv'). 
    Use as ferramentas interativas da página para analisar gráficos 3D/2D, estatísticas 
    de erro e realizar correções de desvio.

================================================================================
