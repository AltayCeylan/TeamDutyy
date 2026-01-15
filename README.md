TeamDuty, şirket içi görev dağıtımı, takip ve raporlama süreçlerini dijitalleştirmek için geliştirilmiş Flutter + Firebase tabanlı bir mobil uygulamadır.<br>
Uygulama; Admin, Müdür ve Çalışan olmak üzere üç farklı rolü destekler ve her role özel yetkilendirme ve arayüz sunar.<br>



 Projenin Amacı<br>
	•	Şirket içi görevlerin departman bazlı ve yetki kontrollü şekilde yönetilmesini sağlamak<br>
	•	Görevlerin durumunu (Pending / Done / İptal / Geciken) anlık olarak takip etmek<br>
	•	Admin ve müdürlerin çalışan performansını şeffaf ve ölçülebilir biçimde izlemesini sağlamak<br>
	•	Gerçek bir kurumsal uygulama mimarisini birebir simüle etmek<br>



 Roller ve Yetkiler<br>

 Admin
	•	Şirket oluşturur ve yönetir<br>
	•	Departman ekler / siler<br>
	•	Müdür ve çalışanları yönetir<br>
	•	Tüm görevleri görür, oluşturur ve iptal edebilir<br>
	•	Genel istatistikleri ve KPI’ları takip eder<br>

<br><img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 003903" src="https://github.com/user-attachments/assets/9ab4811e-7409-4358-a96d-339ae8da2e08" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 003831" src="https://github.com/user-attachments/assets/6d4f7a36-b5b2-4db9-8c6a-c8ff53b66000" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 003839" src="https://github.com/user-attachments/assets/c3cc84ba-5faf-4dc2-9b5f-2693aebbe24a" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 003849" src="https://github.com/user-attachments/assets/04bea805-315a-4ef3-aae1-4a152f17f0c3" /><br>


Müdür<br>
	•	Sadece kendi departmanına ait çalışanları ve görevleri görür<br>
	•	Kendi departmanına görev atar<br>
	•	Görevleri iptal edebilir<br>
	•	Departman bazlı istatistikleri izler<br>
	
<br><img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 004612" src="https://github.com/user-attachments/assets/ab67f739-9cd0-432e-8ae8-342d014d8c07" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 004618" src="https://github.com/user-attachments/assets/181263e1-2f1c-475b-a051-190a0244471f" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 004625" src="https://github.com/user-attachments/assets/0d5fb514-6807-4174-8baf-6a5e6bc45acb" /><br>

Çalışan<br>
	•	Sadece kendisine atanmış görevleri görür<br>
	•	Görevleri tamamlayabilir<br>
	•	Görev durumlarını ve kalan süreyi takip eder<br>
<br><img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 005229" src="https://github.com/user-attachments/assets/00831ff9-531e-47aa-8de2-f8695da1bc1c" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 005236" src="https://github.com/user-attachments/assets/dd4852da-12b6-4189-9ba3-c5660d921000" />
<img width="150" height="300" alt="Ekran görüntüsü 2026-01-16 005224" src="https://github.com/user-attachments/assets/0a6eb613-aee1-495c-8f00-56a18021a67d" /><br>



Görev Yönetimi Özellikleri<br>
	•	Görev oluşturma (başlık, açıklama, son tarih, atanan kişi)<br>
	•	Görev durumları:<br>
	•	Pending<br>
	•	Done<br>
	•	İptal (Admin / Müdür)<br>
	•	Geciken görev tespiti (otomatik)<br>
	•	Görev iptalinde:<br>
	•	Kim iptal etti<br>
	•	Ne zaman iptal edildi<br>
	•	Durumun tüm panellerde senkron görünmesi<br>



Arayüz ve Deneyim
	•	Modern, premium, koyu tema<br>
	•	Admin, müdür ve çalışan panellerinde tek tip tasarım dili<br>
	•	Dashboard yapısı:<br>
	•	KPI kartları (Pending, Done, Geciken, Çalışan sayısı)<br>
	•	Hızlı işlem kartları<br>
	•	Profesyonel görev listeleri ve detay sayfaları<br>



Güvenlik ve Altyapı
	•	Firebase Authentication<br>
	•	Cloud Firestore<br>
	•	Rol ve departman bazlı Firestore Security Rules<br>
	•	Manager & Admin yetki ayrımı net şekilde bellidir<br>
	


 Sonuç

TeamDuty, sadece bir görev listesi uygulaması değil;
kurumsal süreçleri, rol yönetimini ve departman mantığını birebir simüle eden,
gerçek hayatta kullanılabilecek seviyede ölçeklenebilir bir yönetim uygulamasıdır.
