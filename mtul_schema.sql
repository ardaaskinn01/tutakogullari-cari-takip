-- Metretül Fiyat Listesi
-- Kategoriler: 'standard', 'gold_oak' (altın meşe), 'anthracite' (antrasit), 'fly_screen' (sineklik)
CREATE TABLE mtul_prices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category TEXT NOT NULL, 
  component_name TEXT NOT NULL,
  unit_price NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Hesaplama Geçmişi (Başlık)
CREATE TABLE mtul_calculations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_name TEXT NOT NULL,
  total_price NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Hesaplama Detayları (Satırlar)
CREATE TABLE mtul_calculation_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  calculation_id UUID REFERENCES mtul_calculations(id) ON DELETE CASCADE NOT NULL,
  component_name TEXT NOT NULL,
  quantity NUMERIC NOT NULL,   -- Adet veya m2
  unit_price NUMERIC NOT NULL, -- O anki birim fiyat (Fiyat değişirse geçmiş bozulmasın diye saklıyoruz)
  total_price NUMERIC NOT NULL -- quantity * unit_price
);

-- RLS Politikaları
ALTER TABLE mtul_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE mtul_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE mtul_calculation_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage mtul_prices" ON mtul_prices FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can manage mtul_calculations" ON mtul_calculations FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can manage mtul_calculation_items" ON mtul_calculation_items FOR ALL USING (auth.role() = 'authenticated');
