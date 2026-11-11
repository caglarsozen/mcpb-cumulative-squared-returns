# Dondurulmuş MCPB geliştirme deneyi — 25 Ekim 2026

Bu metin yeni adayın test kayıpları hesaplanmadan önce yazılmıştır. Dış ön kayıt değildir. Aynı 2019–2024 verilerindeki eski sonuçlar bilinmektedir; yeni çalışma keşifseldir.

## Ana aday ve gerekçe

MCPB (Maturity-Calibrated Positive Blend) iki değişiklik yapar: her ufukta yalnız o ufkun olgun etiketlerini kullanır; pozitif ridge-PAV/EWMA katsayılarının toplamını 1'e sabitlemeyerek toplam tahmin seviyesini kalibre eder. Her origin kapanışında güncellenir. H=10/20/30/40 için ayrı katsayılar öğrenilir; her yol içinde iki katsayı ufuk boyunca sabittir. Bütün 15 varlık korunur.

R(s,h), E(s,h) asıl geçmiş native ridge-PAV ve EWMA tahminleridir. I(t,h), native bankada s+h<=t sağlayan en son en fazla 252 origindir. Ufuk başına ortalama kayıp eşit ağırlıkla birleştirilir:

J_t(beta) = H^(-1) sum_h |I(t,h)|^(-1) sum_{s in I(t,h)} [Y(s,h)-beta_R R(s,h)-beta_E E(s,h)]^2
            + lambda_t ||beta-(0,1)||^2, beta_R,beta_E>=0.

lambda_t=kappa*trace(Q_t)/2; kappa=10^(-4) ana, 10^(-6) ve 10^(-2) yalnız duyarlılık. Q_t, yukarıdaki iki değişkenli ağırlıklı tasarım Gram matrisidir. Düzenleme ölçekle birlikte değişir ve kollinear iki uzman için benzersiz çözüm sağlar. Bu sayısal düzenleme doğruluk garantisi değildir. Pozitif katsayılı iki monoton yolun toplamı monoton ve negatif olmayan bir yoldur; katsayı toplamının 1 olması gerekmez.

Her ufuk en son kendi olgun etiketlerini kullandığından kayıp pencereleri farklı originlerden oluşur. Bu kriter, sabit bir 252×H tam dikdörtgenin kaybıyla aynı değildir; tüm yol MSE'siyle gelecekte üstünlük iddiası çıkarılmaz. Güncel günün kapanış fiyatı bilgi kümesine dahildir; origin t'nin geleceği t+1'de başlar. Etiketler s+h=t olduğunda kullanılabilir.

## Sabit kontroller

Ridge, Ridge-PAV, EWMA, orijinal aylık RidgeEWMA (Hmax=40 olgunluğu), DailyMix40 (günlük, aynı 40 gecikme), DailyMixH (günlük, tüm yol H olgunluğu), MaturityMix (ufka göre olgunluk, katsayı toplamı 1), CalEWMA (aynı olgunlukla yalnız EWMA seviyesi), NNLS_FullH (pozitif iki katsayı, yalnız tam H yolları), ana MCPB ve iki kappa duyarlılığı.

Ana aday başarısız olursa daha iyi görünen kontrol veya kappa ana yöntem seçilmeyecektir. Testten kötü çıkan varlıklar çıkarılmayacaktır.

## Kapsam ve çıkarım

15 varlık × 4 ufuk × expanding/rolling =120 durum. Native ridge/EWMA bankaları daha önce doğrulanmış aynı geçmiş tahminlerden alınabilir; kod sıfırdan da üretebilir. Dört eski kontrolün n, PathMSE, H1, H1–5, QLIKE değerleri 120 durumdaki referansla eşleşmek zorundadır (2.400 karşılaştırma).

Ana çıkarım ailesi H=30 expanding L=30'da MCPB–EWMA ve MCPB–RidgeEWMA: toplam 30 iki yönlü test; Holm birlikte. B=4.999, moving blocks L=H ana, 2H/3H duyarlılık. Bileşen ailesi MCPB'nin MaturityMix, NNLS_FullH, CalEWMA ve DailyMix40'a karşı 60 testi; ayrı Holm. Diğer H, rolling ve QLIKE ikincildir. Dondurulmuş gerçekleşmiş kayıplara koşullu bootstrap, tüm model eğitimini yeniden örneklemeyen belirsizliktir.

Bu değişiklikler bir algoritmik geliştirme adayıdır; pozitif regresyon, forecast combination veya delayed feedback literatürünün icadı olduğu iddia edilmeyecektir. Yeni bağımsız test dönemi olmadan teyit edilmiş genel üstünlük veya gönderime hazır makale sonucu çıkarılmayacaktır.
