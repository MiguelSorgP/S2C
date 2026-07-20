% GERARVIDEOS - Simulador de Transmissão de Vídeos S2C (Screen-to-Camera).
% Este script simula o lado do transmissor em um sistema de comunicações
% ópticas por câmera (OCC) baseado em tela. Ele realiza a modulação de
% dados (símbolos) usando BPPM com inserção de pilotos físicos para correção
% de ambiguidades geométricas e de escala, constrói o tensor de transmissão
% pelo produto de Khatri-Rao do vídeo original e da mensagem (modelo PARAFAC),
% simula a degradação espacial (borramento) pelo canal óptico e grava o vídeo
% final em formato AVI não compactado para posterior processamento na recepção.

clc;
clear all; %close all;
addpath(fullfile(pwd, 'funcoes'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parâmetros da execução e protocolo
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Flag que indica se a mensagem é aleatória (1) ou definida (0)
% Se for definida (0), a mensagem será gerada com a função SOCC_messageDefined
mensagemAleatoria = 0;

videoorigin = 0; % = 1 (real); =0 (sintético em escala de cinza)

F = 10; % Máximo número de frames para a captura. Quanto maior número de frames, mais pesado fica o programa.

Mmax  = 8; % Dimensoes maximas da tela
Nmax  = 8; % Dimensoes maximas da tela

S = 10; P = 2; M = 4; N = 4;  % Dimensoões de cada bloco de vídeo
K = S*P;              % Número de pulsos por pixel (subquadros).

factor = 0;

% Escolha do protocolo OCC segmentado
prot = 1;           %prot = 1 (OCC-KRF apenas); prot = 2 (OCC-ALS apenas); prot = 3 (Híbrido OCC-ALS e OCC-KRF)

% Níveis de borramento
% sem borramento (simValor=1), borramento moderado (simValor=2) e
% borramento intenso (simValor=3)
simValor = 1;

fps = 30; % Taxa de quadros do vídeo gerado

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inicialização e Processamento
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Criação do objeto VideoReader para a leitura dos quadros do arquivo.avi ou .mp4 se necessário.
if videoorigin == 1
    %OriginalVideo = VideoReader('xylophone.mp4');
    OriginalVideo = VideoReader('shuttle.avi');
    %OriginalVideo = VideoReader('MotoGP.avi');
    %OriginalVideo = VideoReader('foreman.avi');
end

% Ajuste de simulação
if simValor == 1
    mask   = 1;
    scale = 1;
elseif simValor == 2
    mask   =  fspecial('disk',1);
    scale = 1;
elseif simValor == 3
    mask   =  fspecial('disk',2);
    scale = 1;
elseif simValor == 4
    mask   = 1;
    scale = 0.5;
elseif simValor == 5
    mask   =  fspecial('disk',1);
    scale = 0.5;
elseif simValor == 6
    mask   =  fspecial('disk',2);
    scale = 0.5;
end

% Matrizes de métricas inicializadas com tamanho correspondente a imax = 1
symbolNMSE = zeros(1, Mmax/M, Nmax/N);
symbolNMSE2 = zeros(1, 1);
videoNMSE = zeros(1, Mmax/M, Nmax/N);
SER = zeros(1, Mmax/M, Nmax/N);
SERdiv = zeros(1, 1);

% Teste com vídeo real ou sintético
if videoorigin == 1
    ii = 1;
    while hasFrame(OriginalVideo) && (ii <= F)
        img = readFrame(OriginalVideo);
        img2 = 255*im2double(rgb2gray(img));
        V4D(:,:,:,ii) = imresize(img2,[Mmax Nmax]);
        ii = ii + 1;
    end
    clear img
    [Mmax, Nmax, C, F] = size(V4D);
else
    V4D = 255*unifrnd(0,1,[Mmax Nmax 1 F]);
end

Aux = zeros(K, N*M);

% Inicializacao canal/degradcao
Haux = zeros(M*N, M*N, 4);
H = zeros(M*N);

if mensagemAleatoria == 1
    [msg, Sm, S0, S1] = SOCC_message(M, N, P, K, S, 'BPPM', factor);
else
    [msg, Sm, S0, S1] = SOCC_messageDefined(M, N, P, K, S, 'BPPM', factor);
end

cont = 0;
% 4 blocos dos cantos
for blci = 1:(Mmax/M-1):Mmax/M
    for blcj = 1:(Nmax/N-1):Nmax/N

        cont = cont+1;

        [vgray, V4D_gray] = bloco_extraction(V4D, M, N, F, blci, blcj);

        % Ajuste do protocolo (algoritmo) nos blocos dos cantos da tela
        if prot == 1
            flag = 1; % OCC-KRF
        elseif (prot == 2) || (prot == 3)
            flag = 2; % OCC-ALS
        else
            disp('Erro de escolha de protocolo')
            flag = 0;
        end

        % Passando 300 como SNR dummy (pois é ignorado no OCC_SRRsemRuido)
        [Erro, erro_S, erro_V, Bmod, Cmod, Ha, Aux2] = OCC_SRRsemRuido(flag, M, N, K, F, scale, mask, vgray, Sm, eye(M*N), 300);

        video_recon((blci-1)*M+1:blci*M, (blcj-1)*N+1:blcj*N, :) = round(reshape(Cmod.', M, N, F));
        V4D_OCC((blci-1)*M+1:blci*M, (blcj-1)*N+1:blcj*N, :) = reshape(Aux2, M, N, F*K);

        Haux(:,:,cont) = Ha;
        H = H+Ha/4;

        Aux = Aux + Bmod/((Mmax/M)*(Nmax/N));

        symbolNMSE(1, blci, blcj) = symbolNMSE(1, blci, blcj) + erro_S;
        videoNMSE(1, blci, blcj) = videoNMSE(1, blci, blcj) + erro_V;
        SER(1, blci, blcj) = SER(1, blci, blcj) + SER_OCC(Sm, S0, S1, Bmod, P, M, N, S);
    end
end

% Segmentação de blocos restantes
for blci = 1:Mmax/M
    for blcj = 1:Nmax/N

        if ~((blci == 1) && (blcj == 1)) && ~((blci == Mmax/M) && (blcj == Nmax/N)) && ~((blci == 1) && (blcj == Nmax/N)) && ~((blci == Mmax/M) && (blcj == 1))

            [vgray, V4D_gray] = bloco_extraction(V4D, M, N, F, blci, blcj);

            % Ajuste do protocolo (algoritmo) nos blocos restantes da tela
            if (prot == 1) || (prot == 3)
                flag = 1; % OCC-KRF
            elseif prot == 2
                flag = 2; % OCC-ALS
            else
                disp('Erro de escolha de protocolo')
                flag = 0;
            end

            % Passando 300 como SNR dummy (pois é ignorado no OCC_SRRsemRuido)
            [~, erro_S, erro_V, Bmod, Cmod, ~, Aux2] = OCC_SRRsemRuido(flag, M, N, K, F, scale, mask, vgray, Sm, H, 300);

            video_recon((blci-1)*M+1:blci*M, (blcj-1)*N+1:blcj*N, :) = round(reshape(Cmod.', M, N, F));
            V4D_OCC((blci-1)*M+1:blci*M, (blcj-1)*N+1:blcj*N, :) = reshape(Aux2, M, N, F*K);

            Aux = Aux + Bmod/((Mmax/M)*(Nmax/N));

            symbolNMSE(1, blci, blcj) = symbolNMSE(1, blci, blcj) + erro_S;
            videoNMSE(1, blci, blcj) = videoNMSE(1, blci, blcj) + erro_V;
            SER(1, blci, blcj) = SER(1, blci, blcj) + SER_OCC(Sm, S0, S1, Bmod, P, M, N, S);
        end
    end
end

Aux = Aux * diag(1./Aux(1,:));

symbolNMSE2(1) = (norm(Sm-Aux, 'fro')/norm(Sm, 'fro'))^2;
SERdiv(1) = SER_OCC(Sm, S0, S1, Aux, P, M, N, S);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Salvamento Seguro de Vídeo e Dados
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

folder = 'videosGerados';
if ~exist(folder, 'dir')
    mkdir(folder);
end

V = uint8(V4D_OCC); % Convertendo para uint8

videoBaseName = sprintf('video_Mmax%d_Nmax%d_M%d_N%d_F%d', Mmax, Nmax, M, N, F);
videoFileName = fullfile(folder, [videoBaseName, '.avi']);
dataFileName = fullfile(folder, ['dados_', videoBaseName, '.mat']);

v = 1;
while exist(videoFileName, 'file') || exist(dataFileName, 'file')
    videoFileName = fullfile(folder, sprintf('%s_%d.avi', videoBaseName, v));
    dataFileName = fullfile(folder, sprintf('dados_%s_%d.mat', videoBaseName, v));
    v = v + 1;
end

% Salva o vídeo codificado
VidObj = VideoWriter(videoFileName, 'Uncompressed AVI');
VidObj.FrameRate = fps;
open(VidObj);
for f = 1:size(V, 3)
    writeVideo(VidObj, V(:, :, f));
end
close(VidObj);

% Salva os dados do workspace
save(dataFileName);

disp(['Vídeo salvo em: ', videoFileName]);
disp(['Dados salvos em: ', dataFileName]);
