-- Transaction Type enum'ını güncelle (Eskisini yeniden adlandırıp yenisini oluşturuyoruz)
-- Dikkat: Bu işlem eski 'goods_in' ve 'goods_out' verilerini geçersiz kılar.
-- Temiz bir başlangıç için önce transactions tablosunu temizliyoruz (Tercihe bağlı, ama türler değişeceği için gerekli).
TRUNCATE TABLE transactions;

ALTER TYPE transaction_type RENAME TO transaction_type_old;

CREATE TYPE transaction_type AS ENUM ('income', 'expense');

-- Transactions tablosundaki type sütununu güncelle
ALTER TABLE transactions 
  ALTER COLUMN type TYPE transaction_type 
  USING (CASE 
    WHEN type::text = 'money_in' THEN 'income'::transaction_type
    WHEN type::text = 'money_out' THEN 'expense'::transaction_type
    ELSE 'income'::transaction_type -- Mal giriş/çıkışları varsayılan gelire dönüşür veya silinir
  END);

DROP TYPE transaction_type_old;

-- Payment Method enum'ı oluştur
CREATE TYPE payment_method AS ENUM ('cash', 'credit_card', 'check_note');

-- Transactions tablosuna payment_method sütunu ekle
ALTER TABLE transactions 
ADD COLUMN payment_method payment_method NOT NULL DEFAULT 'cash';

-- RLS Politikalarını Güncelle (İhtiyaç varsa, mevcutlar genellikle yeterlidir)
