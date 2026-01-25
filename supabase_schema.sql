-- 1. İşlem Tipleri için Enum Oluşturma
CREATE TYPE transaction_type AS ENUM ('money_in', 'money_out', 'goods_in', 'goods_out');

-- 2. Profiller Tablosu (Kullanıcı Rolleri için)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) NOT NULL PRIMARY KEY,
  email TEXT,
  full_name TEXT, -- Yeni eklenen Ad Soyad sütunu
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. İşlemler (Kasa Defteri) Tablosu
CREATE TABLE transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type transaction_type NOT NULL,
  amount NUMERIC NOT NULL,
  description TEXT,
  created_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Yönetici Profilini Ekleme
INSERT INTO profiles (id, email, full_name, role)
VALUES (
  '6a5a265a-9aab-4e91-ac9e-961ad3ee5e6d', 
  'yonetici@example.com',
  'Yönetici',
  'admin'
);

-- 5. Row Level Security (RLS) Politikaları (Opsiyonel ama önerilir)
-- Tabloları güvenli hale getir
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Okuma Politikaları (Şimdilik herkes her şeyi okuyabilsin, sonra kısıtlarız)
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Transactions are viewable by everyone" ON transactions FOR SELECT USING (true);

-- Yazma Politikaları
-- Sadece admin transaction ekleyebilir veya kullanıcı kendi işlemini ekleyebilir mantığı backend kodunda da kontrol edilecek.
-- Şimdilik insert işlemini herkese açıyoruz (Authenticated users only)
CREATE POLICY "Authenticated users can insert transactions" ON transactions FOR INSERT WITH CHECK (auth.role() = 'authenticated');
