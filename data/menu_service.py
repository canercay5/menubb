import openpyxl
import json
import re
from datetime import datetime

class MenuDataExtractor:
    """Excel verilerini JSON formatına dönüştüren Domain Service."""
    
    def __init__(self, file_path):
        self.file_path = file_path
        self.wb = openpyxl.load_workbook(file_path, data_only=True)
        self.menu_registry = {}

    def _get_formatted_date(self, cell_value):
        if isinstance(cell_value, datetime):
            return cell_value.strftime('%Y-%m-%d')
        if isinstance(cell_value, str):
            match = re.search(r'(\d{4}-\d{2}-\d{2})', cell_value)
            return match.group(1) if match else None
        return None

    def extract_aksam(self):
        sheet = self.wb['AKŞAM MENÜ']
        # M4 (Col 13) Perşembe ise, Pazartesi A (Col 1)'den başlar.
        row_starts = [4, 13, 22, 31, 40]
        col_starts = [1, 5, 9, 13, 17, 21, 25] # A, E, I, M, Q, U, Y

        for r_start in row_starts:
            for c_start in col_starts:
                date_str = self._get_formatted_date(sheet.cell(row=r_start, column=c_start).value)
                if date_str:
                    if date_str not in self.menu_registry:
                        self.menu_registry[date_str] = {"kahvalti": [], "aksam": []}
                    
                    # Akşam: Ofset +2 (4. satır tarih, 5. satır başlık, 6. satır yemek)
                    items = []
                    for i in range(2, 7):
                        name = sheet.cell(row=r_start + i, column=c_start).value
                        cal = sheet.cell(row=r_start + i, column=c_start + 1).value
                        if name and str(name).strip().upper() != 'TOPLAM':
                            items.append({"category": "Ana Menü", "name": str(name).strip(), "calories": f"{cal} kcal"})
                        
                        s_name = sheet.cell(row=r_start + i, column=c_start + 2).value
                        s_cal = sheet.cell(row=r_start + i, column=c_start + 3).value
                        if s_name and str(s_name).strip().upper() != 'TOPLAM':
                            items.append({"category": "Salatbar", "name": str(s_name).strip(), "calories": f"{s_cal} kcal"})
                    self.menu_registry[date_str]["aksam"] = items

    def extract_kahvalti(self):
        sheet = self.wb['KAHVALTI']
        # H3 (Col 8) Perşembe ise, 2 sütunluk bloklarda Pazartesi B (Col 2)'den başlar.
        row_starts = [3, 12, 21, 30, 39]
        col_starts = [2, 4, 6, 8, 10, 12, 14] # B, D, F, H, J, L, N

        for r_start in row_starts:
            for c_start in col_starts:
                date_str = self._get_formatted_date(sheet.cell(row=r_start, column=c_start).value)
                if date_str:
                    if date_str not in self.menu_registry:
                        self.menu_registry[date_str] = {"kahvalti": [], "aksam": []}
                    
                    # Kahvaltı: Ofset +1 (3. satır tarih, 4. satır yemek - başlık yok)
                    items = []
                    for i in range(1, 8): 
                        name = sheet.cell(row=r_start + i, column=c_start).value
                        cal = sheet.cell(row=r_start + i, column=c_start + 1).value
                        if name and str(name).strip().upper() != 'TOPLAM':
                            items.append({"category": "Kahvaltılık", "name": str(name).strip(), "calories": f"{cal} kcal"})
                    self.menu_registry[date_str]["kahvalti"] = items

    def save_json(self, output_path):
        # Tarihe göre sıralayıp kaydedelim
        sorted_data = dict(sorted(self.menu_registry.items()))
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(sorted_data, f, ensure_ascii=False, indent=2)

# --- Uygulama Noktası ---
if __name__ == "__main__":
    extractor = MenuDataExtractor('subat.xlsx')
    extractor.extract_aksam()
    extractor.extract_kahvalti()
    extractor.save_json('menu.json')
    print("Veriler başarıyla analiz edildi ve menu.json oluşturuldu.")