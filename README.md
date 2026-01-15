TeamDuty, şirket içi görev dağıtımı, takip ve raporlama süreçlerini dijitalleştirmek için geliştirilmiş Flutter + Firebase tabanlı bir mobil uygulamadır.
Uygulama; Admin, Müdür ve Çalışan olmak üzere üç farklı rolü destekler ve her role özel yetkilendirme ve arayüz sunar.



 Projenin Amacı
	•	Şirket içi görevlerin departman bazlı ve yetki kontrollü şekilde yönetilmesini sağlamak
	•	Görevlerin durumunu (Pending / Done / İptal / Geciken) anlık olarak takip etmek
	•	Admin ve müdürlerin çalışan performansını şeffaf ve ölçülebilir biçimde izlemesini sağlamak
	•	Gerçek bir kurumsal uygulama mimarisini birebir simüle etmek



 Roller ve Yetkiler

 Admin
	•	Şirket oluşturur ve yönetir
	•	Departman ekler / siler
	•	Müdür ve çalışanları yönetir
	•	Tüm görevleri görür, oluşturur ve iptal edebilir
	•	Genel istatistikleri ve KPI’ları takip eder

  ![Alt](Ekran görüntüsü 2026-01-16 003903.png)

Müdür
	•	Sadece kendi departmanına ait çalışanları ve görevleri görür
	•	Kendi departmanına görev atar
	•	Görevleri iptal edebilir
	•	Departman bazlı istatistikleri izler

Çalışan
	•	Sadece kendisine atanmış görevleri görür
	•	Görevleri tamamlayabilir
	•	Görev durumlarını ve kalan süreyi takip eder



Görev Yönetimi Özellikleri
	•	Görev oluşturma (başlık, açıklama, son tarih, atanan kişi)
	•	Görev durumları:
	•	⏳ Pending
	•	✅ Done
	•	❌ İptal (Admin / Müdür)
	•	Geciken görev tespiti (otomatik)
	•	Görev iptalinde:
	•	Kim iptal etti
	•	Ne zaman iptal edildi
	•	Durumun tüm panellerde senkron görünmesi



Arayüz ve Deneyim
	•	Modern, premium, koyu tema
	•	Admin, müdür ve çalışan panellerinde tek tip tasarım dili
	•	Dashboard yapısı:
	•	KPI kartları (Pending, Done, Geciken, Çalışan sayısı)
	•	Hızlı işlem kartları
	•	Profesyonel görev listeleri ve detay sayfaları



Güvenlik ve Altyapı
	•	Firebase Authentication
	•	Cloud Firestore
	•	Rol ve departman bazlı Firestore Security Rules
	•	Manager & Admin yetki ayrımı net şekilde bellidir
	


 Sonuç

TeamDuty, sadece bir görev listesi uygulaması değil;
kurumsal süreçleri, rol yönetimini ve departman mantığını birebir simüle eden,
gerçek hayatta kullanılabilecek seviyede ölçeklenebilir bir yönetim uygulamasıdır.
