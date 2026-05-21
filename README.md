# EstimaTek - Interactive CAD Canvas & Cost Estimator

EstimaTek adalah aplikasi berbasis Flutter yang dirancang khusus untuk membantu kontraktor, arsitek, dan produsen kusen dalam merancang struktur jendela, pintu, maupun sliding secara interaktif sekaligus mendapatkan kalkulasi estimasi biaya produksi secara *real-time*.

Aplikasi ini mengadopsi sistem pengerjaan berbasis CAD modern mirip **WindowDraw**, berpindah dari penggambaran kustom pasif menjadi kanvas berbasis objek interaktif (*Object-Based Interactive Canvas*).

---

## 🚀 Fitur Utama

### 1. Interactive Object-Based CAD Canvas
Kanvas interaktif sepenuhnya yang mendukung hirarki objek terstruktur (`DesignObject`) mulai dari Induk Frame, Mullion (pembatas tengah), Panel Kaca, hingga jenis bukaan (*Opening Items*).
* **Hit-Testing Akurat:** Mendukung seleksi objek dari daun terdalam (*bottom-up traversal*) untuk mempermudah pemilihan komponen kecil di dalam frame besar.
* **Transformasi Koordinat Modern:** Menggunakan proyeksi matriks inversi (`TransformationController`) untuk menerjemahkan koordinat ketukan layar (*screen space*) menjadi koordinat kanvas (*canvas space*) secara *pixel-perfect* pada tingkat *zoom* atau *pan* berapa pun.
* **Dynamic Resizing & Dragging:** Geser posisi frame, tarik *resize handles* untuk mengubah dimensi, atau geser pembatas mullion untuk menyesuaikan ukuran sub-panel secara fleksibel.

### 2. Multi-Tool Interaction Modes
Sistem interaksi kanvas dikendalikan melalui mode alat (*Tool Modes*) yang dinamis:
* `SELECT` : Memilih frame atau panel, menampilkan *resize handles*, batas seleksi, dan menggeser posisi mullion.
* `FRAME` : Sentuh dan tarik (*touch-and-drag*) di area kosong untuk menggambar rangka (*frame*) baru dilengkapi fitur *snapping*.
* `MULLION` : Ketuk pada panel untuk membaginya menjadi beberapa sub-panel baik secara Vertikal (Split V) maupun Horizontal (Split H).
* `WINDOW / DOOR / SLIDING` : Ketuk panel untuk menerapkan tipe bukaan (Casement, Swing Door, Sliding, Fixed Glass, Louvre).
* `DELETE` : Hapus instan komponen pembatas atau satukan kembali panel yang terbagi.

### 3. Real-Time Cost Estimation & PDF Reporting
Setiap perubahan dimensi, penambahan material kusen, jenis kaca, atau tipe bukaan aksesoris akan langsung memicu kalkulasi ulang biaya secara instan di latar belakang. Data desain terintegrasi penuh dengan sistem *pricing* dan generator dokumen laporan penawaran PDF tanpa merusak struktur database JSON yang sudah ada.

---

## 🛠️ Tech Stack & Arsitektur

* **Framework:** Flutter (Dart)
* **Rendering Engine:** Impeller (Vulkan/Metal Backend)
* **Canvas State Management:** Immutable State (Bloc/Cubit) dengan Virtual Rendering Layer
* **Sistem Koordinat:** `Matrix4` Inversion Projection via `TransformationController`
* **Grafis Komponen:** `CustomPainter` yang dioptimalkan menggunakan `RepaintBoundary` untuk meminimalisir *jank/lag* performa render saat proses *dragging*.

---

## 📂 Struktur Direktori Fitur (`Design Builder`)

```text
lib/features/design_builder/
├── data/
│   └── models/
│       └── design_models.dart      # Definisi DesignObject, ObjectType, dan State Mapping
└── presentation/
    ├── pages/
    │   └── design_builder_page.dart # Kontroler utama Canvas, GestureDetector, dan ToolMode
    └── widgets/
        └── canvas_painter.dart     # CustomPainter penanganan rendering grafis objek

Langkah Memulai (Development)
Clone Repositori:

Bash
git clone [https://github.com/username/estimatek.git](https://github.com/username/estimatek.git)
cd estimatek
Ambil Dependencies:

Bash
flutter pub get
Jalankan Aplikasi ke Perangkat:

Bash
flutter run
Tips: Tekan R (kapital) pada terminal untuk melakukan Hot Restart saat menguji perubahan logika state kanvas agar memori koordinat ter-reset dengan bersih.

💡 Catatan Kontribusi & Alur Kerja Git
Selalu gunakan pencabangan (branch) baru untuk setiap fitur atau perbaikan bug: git checkout -b feature/nama-fitur.

Pastikan melakukan analisis kode sebelum melakukan push: flutter analyze.

Jika terjadi penguncian interaksi (canvas freeze) setelah pembuatan objek pertama, periksa hierarki hit-testing pada komponen penampung agar tidak menelan (swallow) pointer events milik master GestureDetector.
