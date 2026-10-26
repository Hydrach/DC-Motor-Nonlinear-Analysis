
clc;
clear;
close all;

%% DC MOTOR - FINAL ANALIZ
% EEM827 Dogrusal Olmayan Sistemler
% Zaman: mikrosaniye; hiz: RPM. Statik analiz tum tekrarlari kullanir.
% Dinamik analiz ilk tekrarin basamak cevabini kullanir.

dosya = 'MotorsData_rev.xlsx';
sayfa = 'StepNoLoad-MotorA';

veri = readtable(dosya, ...
    'Sheet', sayfa, ...
    'VariableNamingRule', 'preserve');

%% 1. STATIK VERI ANALIZI

PWM = zeros(14,1);
Hiz = zeros(14,1);

for k = 0:13

    if k == 0
        h = 'Velocity';
        p = 'PWM';
    else
        h = sprintf('Velocity_%d',k);
        p = sprintf('PWM_%d',k);
    end

    w = veri.(h);
    u = veri.(p);

    gecerli = isfinite(w) & isfinite(u);
    w = w(gecerli);
    u = u(gecerli);

    PWM(k+1) = max(u);

    % Her deney tekrarinin son %20 bolumunu ayri hesapla.
    % Zaman damgasi her tekrar basinda sifirlanir.
    if k == 0
        zamanAdi = 'time';
    else
        zamanAdi = sprintf('time_%d',k);
    end
    tHam = veri.(zamanAdi);
    g = isfinite(tHam) & isfinite(veri.(h)) & isfinite(veri.(p));
    tt = tHam(g);
    ww = veri.(h);
    ww = ww(g);
    sinirlar = [1; find(diff(tt)<0)+1; numel(tt)+1];
    tekrarOrt = zeros(numel(sinirlar)-1,1);
    for r = 1:numel(tekrarOrt)
        a = sinirlar(r);
        b = sinirlar(r+1)-1;
        sonBas = a + floor(0.8*(b-a+1));
        tekrarOrt(r) = mean(ww(sonBas:b));
    end
    Hiz(k+1) = mean(tekrarOrt);

end

%% 2. MODEL KARSILASTIRMASI

p1 = polyfit(PWM,Hiz,1);
p3 = polyfit(PWM,Hiz,3);

y1 = polyval(p1,PWM);
y3 = polyval(p3,PWM);

RMSE1 = sqrt(mean((Hiz-y1).^2));
RMSE3 = sqrt(mean((Hiz-y3).^2));

SST = sum((Hiz-mean(Hiz)).^2);

R2_1 = 1-sum((Hiz-y1).^2)/SST;
R2_3 = 1-sum((Hiz-y3).^2)/SST;

fprintf('\nMODEL SONUCLARI\n');
fprintf('Dogrusal RMSE: %.4f\n',RMSE1);
fprintf('Kublik RMSE: %.4f\n',RMSE3);
fprintf('Dogrusal R2: %.4f\n',R2_1);
fprintf('Kublik R2: %.4f\n',R2_3);

%% 3. PWM - HIZ GRAFIGI

figure(1);

plot(PWM,Hiz,'bo-', ...
    'LineWidth',1.8,'MarkerSize',6);

grid on;
xlabel('PWM');
ylabel('Motor Hizi (RPM)');
title('PWM - Motor Hizi Karakteristigi');

exportgraphics(gcf,'Grafik_1_PWM_Hiz.png', ...
    'Resolution',300);

%% 4. MODEL KARSILASTIRMA GRAFIGI

figure(2);

x = linspace(min(PWM),max(PWM),500);

plot(PWM,Hiz,'ko','MarkerFaceColor','k');
hold on;

plot(x,polyval(p1,x),'b--','LineWidth',2);
plot(x,polyval(p3,x),'r-','LineWidth',2);

grid on;
xlabel('PWM');
ylabel('Motor Hizi (RPM)');
title('Dogrusal ve Kublik Model Karsilastirmasi');

legend('Deneysel Veri','Dogrusal Model', ...
    'Kublik Model','Location','best');

exportgraphics(gcf,'Grafik_2_Model.png', ...
    'Resolution',300);

%% 5. DINAMIK ANALIZ

gruplar = [5 8 11];

PWM_d = zeros(3,1);
Tau = zeros(3,1);
Hiz_ss = zeros(3,1);

figure(3);
hold on;

for j = 1:3

    k = gruplar(j);

    t = veri.(sprintf('time_%d',k));
    w = veri.(sprintf('Velocity_%d',k));
    u = veri.(sprintf('PWM_%d',k));

    gecerli = isfinite(t) & isfinite(w) ...
        & isfinite(u);

    t = t(gecerli);
    w = w(gecerli);
    u = u(gecerli);

    % Ilk zaman geri donusune kadar
    idxReset = find(diff(t)<0,1,'first');

    if ~isempty(idxReset)
        t = t(1:idxReset);
        w = w(1:idxReset);
        u = u(1:idxReset);
    end

    % Basamak baslangici
    idx0 = find(u >= 0.5*max(u),1,'first');

    t0 = t(idx0);
    w0 = w(idx0);

    % Kararli durum tahmini
    N = length(w);
    wss = mean(w(floor(0.8*N)+1:end));

    % %63.2 seviyesi
    w63 = w0+0.632*(wss-w0);

    idx63 = find((1:N)' >= idx0 & w>=w63, ...
        1,'first');

    tau = (t(idx63)-t0)/1e6;

    PWM_d(j) = max(u);
    Tau(j) = tau;
    Hiz_ss(j) = wss;

    % Normalize hiz
    t_yeni = (t(idx0:end)-t0)/1e6;
    w_yeni = w(idx0:end);

    wn = (w_yeni-w0)/(wss-w0);

    plot(t_yeni,wn,'LineWidth',2);

end

yline(0.632,'k--');

grid on;
xlabel('Zaman (s)');
ylabel('Normalize Motor Hizi');
title('Normalize Dinamik Tepkiler');

legend('PWM 51','PWM 127','PWM 204', ...
    '%63.2','Location','best');

exportgraphics(gcf,'Grafik_3_Dinamik.png', ...
    'Resolution',300);

%% 6. ZAMAN SABITI GRAFIGI

figure(4);

plot(PWM_d,Tau,'ro-', ...
    'LineWidth',2,'MarkerSize',8);

grid on;
xlabel('PWM');
ylabel('Tahmini Zaman Sabiti (s)');
title('PWM - Zaman Sabiti Iliskisi');

exportgraphics(gcf,'Grafik_4_ZamanSabiti.png', ...
    'Resolution',300);

%% 7. SONUC TABLOLARI

StatikTablo = table(PWM,Hiz);

DinamikTablo = table(PWM_d,Tau,Hiz_ss, ...
    'VariableNames', ...
    {'PWM','ZamanSabiti','KararliDurumHizi'});

disp('STATIK SONUCLAR');
disp(StatikTablo);

disp('DINAMIK SONUCLAR');
disp(DinamikTablo);

%% 8. DOSYALARI KAYDET

writetable(StatikTablo,'Statik_Sonuclar.xlsx');
writetable(DinamikTablo,'Dinamik_Sonuclar.xlsx');

save('DC_Motor_Sonuclar.mat', ...
    'PWM','Hiz','PWM_d','Tau','Hiz_ss', ...
    'RMSE1','RMSE3','R2_1','R2_3','p1','p3');

fprintf('\nANALIZ TAMAMLANDI.\n');
fprintf('Grafikler ve sonuc dosyalari kaydedildi.\n');
