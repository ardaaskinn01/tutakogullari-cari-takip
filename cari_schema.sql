-- Cari Hesap Türleri (Borç / Tahsilat)
CREATE TYPE cari_transaction_type AS ENUM ('debt', 'collection');

-- 1. Cari Hesaplar (Borçlu Kişiler)
CREATE TABLE cari_accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  current_balance NUMERIC DEFAULT 0, -- Pozitif değer alacağı gösterir
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Cari İşlemler (Hareketler)
CREATE TABLE cari_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id UUID REFERENCES cari_accounts(id) ON DELETE CASCADE NOT NULL,
  type cari_transaction_type NOT NULL, -- 'debt' (Alacak Ekle) veya 'collection' (Tahsilat)
  amount NUMERIC NOT NULL CHECK (amount > 0),
  payment_method payment_method, -- Sadece tahsilat ise dolu olur (cash, credit_card, etc.)
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Güvenlik Politikaları (RLS) - Basit Kurulum
ALTER TABLE cari_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cari_transactions ENABLE ROW LEVEL SECURITY;

-- Herkes okuyabilir ve yazabilir (Admin panel olduğu için oturum açmış herkes yetkili)
CREATE POLICY "Authenticated users can manage cari_accounts" ON cari_accounts
  FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can manage cari_transactions" ON cari_transactions
  FOR ALL USING (auth.role() = 'authenticated');
