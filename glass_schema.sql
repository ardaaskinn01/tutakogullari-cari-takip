-- Cam Metrekare Hesaplamaları
CREATE TABLE glass_calculations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_name TEXT NOT NULL,
  width NUMERIC NOT NULL,      -- Metre cinsinden en
  height NUMERIC NOT NULL,     -- Metre cinsinden boy
  m2 NUMERIC NOT NULL,         -- Tek bir camın metrekaresi (width * height)
  quantity NUMERIC NOT NULL,   -- Adet
  total_m2 NUMERIC NOT NULL,   -- Toplam metrekare (m2 * quantity)
  unit_price NUMERIC NOT NULL, -- m2 Birim Fiyatı
  total_price NUMERIC NOT NULL,-- Genel Toplam Fiyat
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS Politikaları
ALTER TABLE glass_calculations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage glass_calculations" 
ON glass_calculations 
FOR ALL 
USING (auth.role() = 'authenticated');
