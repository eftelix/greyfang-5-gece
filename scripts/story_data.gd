class_name StoryData
extends RefCounted
## Story canon + every piece of evidence. The truth (never stated directly):
## - 14.03.2018: Dila Kaya (19, kasiyer, elektronik öğrencisi) found that manager
##   Selim Karaca hid dangerous "Gece Devriye Modu" test results. She stayed late to
##   copy them. At 23:40 Selim started Night Mode with "personel kontrol KAPALI".
## - Night Mode tracks people through the camera network. Technician Hakan Yıldız
##   cut the camera network for 11 minutes (23:47-23:58), blinding the units, and
##   got Dila out through the kitchen service door. She fled and changed her name.
## - Selim deleted the archive (23:30-00:30), shifted CAM3 timestamps and blamed Hakan.
##   Hakan stayed silent to protect Dila. Golden Grayson (prototype G-0, the test
##   unit) holds a corrupted memory of those minutes. Why the units still patrol
##   with Night Mode supposedly removed stays unexplained.

const TYPE_NAMES := {
	"doc": "BELGE", "tape": "SES KAYDI", "footage": "KAMERA KAYDI", "env": "ÇEVRESEL İZ",
	"syslog": "SİSTEM KAYDI", "memory": "BOZUK HAFIZA",
}

const TAGS := ["Dila", "Hakan", "Selim", "Gece Modu", "11 Dakika", "Kayıtlar", "Altın Grayson"]

## night = earliest night it may appear. core = needed for the deduction (guaranteed to
## appear on its night or any later night until found). place = allowed spot kinds.
const CLUES := {
	"c_tape_selim_orient": {
		"night": 1, "core": true, "type": "tape", "voice": "voice_selim", "place": ["surface", "floor"],
		"title": "Oryantasyon Kaseti — 2017",
		"date": "Eylül 2017",
		"tags": ["Selim", "Gece Modu"],
		"text": "[Kaset etiketi: \"YENİ PERSONEL — S.K.\"]\n\nSELİM KARACA: ...Greyfang'e hoş geldiniz. Kasa 23.00'te kapanır, 23.00'ten sonra binada personel kalmaz. Bu kural değil, şart.\n\nGeceleri karakterlerimiz... \"gece moduna\" alınıyor. Deneme aşamasında. Teknik ekip dışında kimse ilgilenmesin, kimse sormasın.\n\n[cızırtı]\n\n...müşteriye, sigortaya, kimseye bundan bahsetmeyin. Kimse sormasın, kimse söylemesin. Afiyet olsun.\n\n[kayıt sonu]",
	},
	"c_news_2018": {
		"night": 1, "core": true, "type": "doc", "place": ["wall", "surface", "floor"],
		"title": "Gazete Kupürü — Mart 2018",
		"date": "17.03.2018",
		"tags": ["Dila", "Hakan", "11 Dakika"],
		"text": "LAHMACUN SALONUNDA GİZEMLİ KAYIP\n\nGreyfang Lahmacun Sarayı'nda kasiyer olarak çalışan 19 yaşındaki Dila K.'den 14 Mart gecesinden beri haber alınamıyor.\n\nİşletme yöneticisi Selim Karaca'nın açıklamasına göre güvenlik kameraları gece 23.47 ile 23.58 arasında, \"bilinçli olarak\" kapatıldı. Olay gecesi binada bulunan gece teknisyeni H.Y. gözaltına alındı, ancak delil yetersizliğinden serbest bırakıldı.\n\nTeknisyenin, kameraları neden kapattığına dair soruları yanıtsız bıraktığı öğrenildi.",
	},
	"c_env_scratch": {
		"night": 1, "core": false, "type": "env", "place": ["wall"],
		"title": "Duvardaki Çentikler",
		"date": "?",
		"tags": ["11 Dakika", "Dila"],
		"label": "IIII IIII I\nKAÇ",
		"text": "Duvarın alt kısmına, yaklaşık bir çocuk boyu yüksekliğinde kazınmış on bir çentik. Altında titrek harflerle tek kelime: \"KAÇ\".\n\nÇentikler aynı aletle, acele içinde yapılmış gibi. Boya yıllar içinde üstlerine dökülmüş; yeni değiller.",
	},
	"c_doc_schedule": {
		"night": 1, "core": false, "type": "doc", "place": ["wall", "surface"],
		"title": "Mart 2018 Vardiya Çizelgesi",
		"date": "Mart 2018",
		"tags": ["Dila", "Selim", "Hakan"],
		"text": "GREYFANG LAHMACUN SARAYI — VARDİYA ÇİZELGESİ (MART 2018)\n\n14 MART ÇARŞAMBA\n  Kasa ............ Dila K.   17:00 – 23:00\n  Mutfak .......... Gülay T.  16:00 – 23:30 (temizlik)\n  Gece teknisyeni . Hakan Y.  22:00 – 06:00\n\nDila'nın satırının yanında kırmızı kalemle, başka bir el yazısıyla:\n\"Kasa sayımı — geç çıkacak. S.K.\"\n\nOysa yöneticinin kendi oryantasyon kuralına göre 23.00'ten sonra binada personel kalmamalı.",
	},
	"c_form_hakan_1": {
		"night": 2, "core": true, "type": "doc", "place": ["surface", "floor", "wall"],
		"title": "Bakım Formu #114 — Gece Modu Testi",
		"date": "02.03.2018",
		"tags": ["Hakan", "Selim", "Gece Modu", "Altın Grayson"],
		"text": "GREYFANG — TEKNİK BAKIM FORMU #114\nTarih: 02.03.2018   Teknisyen: Hakan Yıldız\n\nÜnite: G-0 (Altın prototip Grayson)\nİşlem: Gece Devriye Modu — saha testi\n\nGözlem: Ünite, koridordaki personel mankenini \"İZİNSİZ GİRİŞ\" olarak sınıflandırdı. Takip etti, kollarını kilitledi, bırakmadı. Mankenin göğüs plakası ezildi.\n\nÖNERİ: TEST DERHAL DURDURULMALI. İnsan varken kesinlikle çalıştırılmamalı.\n\nAlttaki yönetici notu (mavi kalem):\n\"Devam. Sigortaya bilgi verilmeyecek. — S.K.\"",
	},
	"c_footage_mismatch": {
		"night": 2, "core": true, "type": "footage", "place": ["surface"],
		"title": "CAM 3 Kaydı — Zaman Uyuşmazlığı",
		"date": "14.03.2018",
		"tags": ["Dila", "11 Dakika", "Kayıtlar"],
		"text": "[DEPO KAMERASI — KURTARILMIŞ TEK KARE]\n\nEkran zaman damgası: 15.03.2018  00:12:09\n\nKarede uzun saçlı genç bir kadın, depo raflarının önünde. Göğsüne bir dosya bastırıyor, kapıya bakıyor. Yaka kartı okunmuyor.\n\nAma arka duvardaki yuvarlak saat 23.44'ü gösteriyor.\n\nKarenin kare sayacı 23.30'dan sonra bir anda 00.12'ye atlıyor. Arada hiçbir kare yok. Biri, kaydın saatini sonradan kaydırmış gibi.",
	},
	"c_statement_cleaner": {
		"night": 2, "core": false, "type": "doc", "place": ["surface", "floor"],
		"title": "Temizlik Görevlisinin İfadesi",
		"date": "16.03.2018",
		"tags": ["Hakan", "Dila"],
		"text": "İFADE TUTANAĞI (SURET)\nİfade veren: Gülay T., temizlik görevlisi\n\n\"Saat on bir buçuk sularında çıkıyordum. Hakan Bey'i mutfak kapısının orada Dila'yla gördüm. Tartışıyorlardı. Hakan Bey kızın kolundan tutmuş, çekiyordu. Dila 'ya seni suçlarlarsa' gibi bir şey dedi. Ben karışmadım, çıktım gittim. Sonrasını bilmiyorum.\"\n\nTutanağın kenarına kurşun kalemle: \"Teknisyen şüpheli.\"",
	},
	"c_form_sensor": {
		"night": 2, "core": true, "type": "doc", "place": ["wall", "surface"],
		"title": "Gece Modu Bağlantı Şeması",
		"date": "2017",
		"tags": ["Gece Modu", "11 Dakika", "Kayıtlar"],
		"text": "DEMİRKOL MEKATRONİK — GECE DEVRİYE MODU / KURULUM NOTU\n\n• Ünitelerin kendi kameraları yoktur. Hedef tespiti ve konum takibi, binanın GÜVENLİK KAMERA AĞI üzerinden yapılır.\n• Kamera ağı kesilirse üniteler hedefi kaybeder ve bulundukları yerde beklemeye geçer.\n• Ağ geri geldiğinde devriye kaldığı yerden devam eder.\n\nKenarda el yazısıyla (H.Y.):\n\"Yani kameralar kapanınca hepsi kör. Unutma.\"",
	},
	"c_dila_nametag": {
		"night": 3, "core": true, "type": "env", "place": ["floor", "surface"],
		"title": "Dila'nın Yaka Kartı",
		"date": "2018",
		"tags": ["Dila"],
		"text": "Kutuların arkasına düşmüş, tozlu bir yaka kartı:\n\n  GREYFANG LAHMACUN SARAYI\n  DİLA — KASA\n\nKlipsine kopmuş bir USB kablosu dolanmış. Kart, depo kamerası karesindeki kadının durduğu rafın hemen dibinde.",
	},
	"c_dila_note": {
		"night": 3, "core": true, "type": "doc", "place": ["surface", "floor"],
		"title": "Defterden Koparılmış Sayfa",
		"date": "13.03.2018",
		"tags": ["Dila", "Selim", "Hakan", "Gece Modu"],
		"text": "(Öğrenci defteri kâğıdı, yuvarlak el yazısı)\n\n13 Mart\nSelim Bey test raporlarını müfettişten saklıyor. Ofis bilgisayarında gördüm: \"insan hedefi\", \"kilitlenme\", \"ezilme\". Biri ölecek.\n\nYarın kasa sayımı bahanesiyle kalıp kopyalarını alacağım. İSG'ye götüreceğim.\n\nHakan Abi'ye söyledim. Yüzü bembeyaz oldu. \"Bu gece sakın kalma\" dedi. Kalmam lazım.",
	},
	"c_syslog_delete": {
		"night": 3, "core": true, "type": "syslog", "place": ["surface"],
		"title": "Silinmiş Komut Geçmişi",
		"date": "15.03.2018",
		"tags": ["Selim", "Kayıtlar", "Gece Modu"],
		"text": "GFNG-SRV01 :: kurtarılan .bash_history parçası\n\n15.03.2018 02:14  kullanıcı: skaraca\n> arsiv sil --kamera TUM --aralik 23:30-00:30\n> zaman_damgasi kaydir CAM3 +00:28\n> gecemodu log temizle --tum\n> history -c\n\n[Son komut geçmişi silmeye çalışmış, ancak sunucu yedeği bu satırları korumuş.]",
	},
	"c_syslog_activate": {
		"night": 3, "core": true, "type": "syslog", "place": ["surface"],
		"title": "Gece Modu Başlatma Kaydı",
		"date": "14.03.2018",
		"tags": ["Selim", "Gece Modu", "Dila"],
		"text": "GFNG-SRV01 :: gecemodu.log (yedek kopya)\n\n14.03.2018 23:38  kasa_cekmecesi ACIK  (terminal: KASA-1)\n14.03.2018 23:40  kullanıcı: skaraca  (uzaktan bağlantı)\n> gecemodu baslat --test --personel_kontrol KAPALI\n  UYARI: binada aktif personel kartı tespit edildi (1)\n  devam edilsin mi? [e/h] e\n14.03.2018 23:41  G-0: devriye başladı\n14.03.2018 23:47  KAMERA AĞI: BAĞLANTI KESİLDİ\n14.03.2018 23:58  KAMERA AĞI: YENİDEN BAĞLANDI",
	},
	"c_email_draft": {
		"night": 3, "core": false, "type": "doc", "place": ["surface", "floor"],
		"title": "Gönderilmemiş E-posta Taslağı",
		"date": "18.03.2018",
		"tags": ["Selim", "Hakan", "Kayıtlar"],
		"text": "Kime: Av. Murat E.\nKonu: teknisyen meselesi\n\nMurat Bey,\nTeknisyen sistemi kendisinin kapattığını kabul ediyor. Neden kapattığını söylemiyor. Bu bizim işimize gelir.\n\nArşiv konusunu ben hallettim, o saatlere dair elde bir şey yok. Kızın ailesi sorarsa kendi isteğiyle ayrıldığını söyleyeceğiz.\n\nDemirkol'un raporlarından kimseye bahsetmeyin.\n— S.K.\n\n[Taslak — gönderilmedi]",
	},
	"c_tape_hakan_1": {
		"night": 4, "core": true, "type": "tape", "voice": "voice_hakan", "place": ["surface", "floor"],
		"title": "Hakan'ın Ses Kaydı — 14 Mart 23:46",
		"date": "14.03.2018",
		"tags": ["Hakan", "Dila", "Gece Modu", "11 Dakika"],
		"text": "[Küçük bir diktafon. Arka planda uğultu, uzaktan metal sesleri.]\n\nHAKAN: ...Selim gece modunu açtı. Kız hâlâ içeride, depoda. Kart okuyucu onu gösteriyor, Selim de biliyor.\n\nKameraları kesersem hepsi kör olur. On dakika... belki on bir. Ondan fazlası olmaz, alarm düşer.\n\n[hızlı nefes, ayak sesleri]\n\nHAKAN: Dila! Bırak o dosyayı— tamam, al, al ama koş. Mutfaktaki servis kapısı. Arkana bakma.\n\nDİLA (uzaktan): Abi, ya seni suçlarlarsa?\n\nHAKAN: Koş dedim!\n\n[kayıt kesilir]",
	},
	"c_tape_hakan_2": {
		"night": 4, "core": true, "type": "tape", "voice": "voice_hakan", "place": ["surface", "floor"],
		"title": "Hakan'ın Ses Kaydı — \"Berk'e\"",
		"date": "2019",
		"tags": ["Hakan", "Dila"],
		"text": "[Kaset kutusunun üstünde kurşun kalemle: \"BERK — büyüyünce\"]\n\nHAKAN: Berk... oğlum. Bunu dinliyorsan, demek ki beni hâlâ merak ediyorsun.\n\nO gece ne olduğunu kimseye anlatmadım. Anlatamazdım. O kız hâlâ korkuyor, hâlâ saklanıyor. Ona söz verdim.\n\nBen kimseye zarar vermedim. Sistemi kapattım, evet. Ama bir insanı kurtarmak için.\n\nBir gün güvende olduğunda, gerçeği o anlatacak. O güne kadar susmak zorundayım. Beni affet.\n\n[kayıt sonu]",
	},
	"c_footage_back_door": {
		"night": 4, "core": false, "type": "footage", "place": ["surface"],
		"title": "Otopark Kamerası — Bağımsız Kayıt",
		"date": "14.03.2018",
		"tags": ["Dila", "Hakan", "11 Dakika"],
		"text": "[ESKİ OTOPARK KAMERASI — ANA SİSTEME BAĞLI DEĞİL, BU YÜZDEN SİLİNMEMİŞ]\n\n14.03.2018  23:51:40\n\nMutfak servis kapısı açılıyor. İki kişi çıkıyor. Kısa boylu olan, göğsünde bir dosyayla sokağa doğru koşuyor; köşede bekleyen bir taksiye biniyor.\n\nUzun boylu olan, teknisyen yeleğiyle, kapıda durup arkasından bakıyor. Sonra yeniden içeri giriyor.\n\n23:52:05 — Taksi uzaklaşıyor.",
	},
	"c_police_statement": {
		"night": 4, "core": false, "type": "doc", "place": ["surface", "floor", "wall"],
		"title": "Hakan Yıldız'ın Emniyet İfadesi",
		"date": "15.03.2018",
		"tags": ["Hakan", "Dila"],
		"text": "İFADE TUTANAĞI (SURET)\nİfade veren: Hakan Yıldız, gece teknisyeni\n\nSoru: Kamera sistemini siz mi kapattınız?\nCevap: Evet, ben kapattım.\n\nSoru: Neden?\nCevap: Bunu söylemeyeceğim.\n\nSoru: Dila Kaya nerede?\nCevap: Bilmiyorum. Ama ben ona zarar vermedim. Ona kimsenin zarar vermesine de izin vermedim.\n\nSoru: Gece modu nedir?\nCevap: Selim Bey'e sorun.",
	},
	"c_postcard": {
		"night": 5, "core": true, "type": "doc", "place": ["surface", "floor", "wall"],
		"title": "Teslim Edilmemiş Kartpostal",
		"date": "2021",
		"tags": ["Dila", "Hakan"],
		"text": "(Yurt dışı pullu bir kartpostal. Adres: \"Hakan Yıldız — Greyfang Lahmacun Sarayı, servis kapısı\". Restoran kapandığı için hiç teslim edilmemiş; posta yığınının içinde.)\n\nHakan Abi,\nİyiyim. Adım artık başka, annemin soyadını kullanıyorum. Raporların kopyaları bende, hâlâ saklıyorum. Zamanı gelince ortaya çıkaracağım.\n\nO on bir dakika için sana borçluyum. Senin adını temizlemeden rahat etmeyeceğim.\n— D.",
	},
	"c_test_report": {
		"night": 5, "core": true, "type": "doc", "place": ["surface", "floor"],
		"title": "Demirkol Test Raporu (Gizli)",
		"date": "Şubat 2018",
		"tags": ["Gece Modu", "Selim", "Altın Grayson"],
		"text": "DEMİRKOL MEKATRONİK — GECE DEVRİYE MODU SAHA TEST RAPORU\nMüşteri: Greyfang Lahmacun Sarayı (S. Karaca)\n\nSonuç: 9 testin 4'ünde insan hedefi \"izinsiz giriş\" olarak sınıflandırıldı. Ünite G-0 bir testte hedefi 6 dakika boyunca bırakmadı.\n\nÖneri: Ürün kullanıma uygun değildir. Kullanım derhal durdurulmalıdır.\n\nKapakta kırmızı damga: \"GİZLİ — S.K. dışında kimse görmeyecek\"",
	},
	"c_env_goldmod": {
		"night": 5, "core": false, "type": "env", "place": ["surface", "floor"],
		"title": "G-0 Bellek Modülü Etiketi",
		"date": "2018",
		"tags": ["Altın Grayson", "Gece Modu"],
		"text": "Söküldükten sonra geri takılmamış bir göğüs paneli. İçindeki bellek modülünün üstünde iki etiket var.\n\nBasılı etiket: \"G-0 BELLEK — 14.03.2018\"\nEl yazısı (Selim'in kırmızı kalemi): \"SİL\"\nAltında başka bir el yazısı (H.Y.): \"Silinmedi. Saklandı.\"\n\nModülün kablosu kopmuş, ama ünite hâlâ elektrik çekiyor gibi.",
	},
	# ---- Golden Grayson memory fragments (only from encounters) ----
	"m_gold_1": {
		"night": 3, "core": false, "type": "memory", "place": [],
		"title": "G-0 Bellek Parçası #1",
		"date": "14.03.2018 23:41",
		"tags": ["Altın Grayson", "Gece Modu", "Dila"],
		"text": "[G-0 :: SENSÖR KAYDI — %31 OKUNABİLİR]\n\n23:41:02  DEVRİYE BAŞLADI\n23:41:15  HEDEF: KASA-1 YAKINI — SINIF: PERSONEL?\n23:41:16  ...PERSONEL KONTROL: KAPALI → SINIF: İZİNSİZ\n23:41:16  TAKİP BAŞLAT\n\n[SES] (genç kadın): \"Selim Bey? Işıklar neden... kim var orada?\"\n\n▒▒▒▒ BELLEK HATASI ▒▒▒▒",
	},
	"m_gold_2": {
		"night": 4, "core": false, "type": "memory", "place": [],
		"title": "G-0 Bellek Parçası #2",
		"date": "14.03.2018 23:47",
		"tags": ["Altın Grayson", "11 Dakika", "Hakan", "Dila"],
		"text": "[G-0 :: SENSÖR KAYDI — %22 OKUNABİLİR]\n\n23:46:58  HEDEF: DEPO — MESAFE 4.1 m\n23:47:00  KAMERA AĞI: BAĞLANTI YOK\n23:47:00  HEDEF KAYBOLDU. BEKLEMEDE.\n\n[SES] (kadın): \"Abi, ya seni suçlarlarsa?\"\n[SES] (erkek): \"Koş Dila. Arkana bakma.\"\n\n23:47:xx — 23:58:xx  ▒▒▒▒▒▒▒▒▒▒▒▒ (11 DAKİKA)",
	},
	"m_gold_3": {
		"night": 5, "core": false, "type": "memory", "place": [],
		"title": "G-0 Bellek Parçası #3",
		"date": "14.03.2018 23:58",
		"tags": ["Altın Grayson", "Selim", "Hakan", "Kayıtlar"],
		"text": "[G-0 :: SENSÖR KAYDI — %9 OKUNABİLİR]\n\n23:58:03  KAMERA AĞI: YENİDEN BAĞLANDI\n23:58:03  HEDEF: YOK\n\n[SES] (yönetici): \"Hakan, ne yaptın sen? ...Kız nerede?\"\n[SES] (teknisyen): \"Gitti.\"\n[SES] (yönetici): \"Kayıtları ben hallederim. Sen sadece sus.\"\n\n▒▒▒ ... DEVRİYE DEVAM EDİYOR. KİMSE KAPATMADI. KİMSE KAPATMADI. KİMSE ▒▒▒",
	},
}

## Owner voicemails (tutorial / mood) played at the start of each night.
const VOICEMAILS := {
	1: "NERMİN AKSOY (yeni işletmeci): Berk, merhaba! İlk gecen. Mekânı yeniden açmadan önce sadece birinin bina boş değilmiş gibi durmasını istiyoruz, o kadar.\n\nOfiste her şey var: sol ve sağ kapılar [Q / E], koridor ışıkları [A / D], kamera tableti [BOŞLUK]. Elektrik sınırlı, eski tesisat; kapı, ışık ve kamera akımı yer, idareli kullan.\n\nKarakterler... şey. Eski sahiplerden kaldılar. Geceleri biraz \"dolaşabiliyorlar\". Sensörleri kafayı yemiş, seni hırsız sanabilirler. Kapıdan içeri girmelerine izin verme, yeter.\n\nBir de korsan köşesi; Kaptan Rook'un perdesini ara ara kameradan kontrol et. Uzun süre bakılmazsa... huysuzlanıyor.\n\nEski evraklar falan görürsen dokunma. Ya da... bilmiyorum, sen bilirsin. İyi geceler.",
	2: "NERMİN AKSOY: Berk, dün gece için sağ ol. Sabah kameraların kaydına baktım, bazı eski klasörler yer değiştirmiş, sen mi oynadın? Neyse.\n\nMutfak kamerası arızalı, bazen görüntü gidip geliyor; Brutus o taraftan geçerken genelde ses yapar, tepsisi falan. Kulağını aç.\n\nBu arada... babanın eskiden burada çalıştığını öğrendim. Yanlış anlama, sadece... dikkatli ol, olur mu?",
	3: "NERMİN AKSOY: Bu gece tadilatçılar depoyu boşaltmaya başladı, ortalık karışık. Eğer bir şey bulursan sabah bana söyle.\n\nAh, bir de: Grayson. Diğerleri sahneden inmeden pek kıpırdamaz ama kıpırdarsa... kameradan gözünü ayırmadığın sürece durur gibi. Arkanı döndüğünde ilerler. Sağ tarafa dikkat.\n\nVe Berk... sistemde \"G-0\" diye bir ünite görünüyor. Envanterde öyle bir şey yok. Görürsen bana haber ver.",
	4: "NERMİN AKSOY: Berk. Bugün bir avukat aradı, Selim Karaca adına. Mekânda \"eski evrakların\" bulunup bulunmadığını sordu. Ben yok dedim.\n\nBen yok dedim, çünkü sen bulduysan, bunun sana ait olduğunu düşünüyorum.\n\nBu gece hepsi daha hareketli. Elektriği idareli kullan. Ve kapıyı kapatmak için onları görmeyi bekleme; seslere güven.",
	5: "NERMİN AKSOY: Son gece. Sabah altıda sahne ekibi geliyor, her şeyi söküp yeniden yapacaklar. Burada ne varsa bu gece var, yarın yok.\n\nBerk, babanı tanımadım. Ama ne bulduysan, onu bu gece tamamla.\n\nVe o altın şey... kameralarda görürsen, ona uzun bakma. Ama bir şey söylemeye çalışıyorsa... dinle.\n\nİyi şanslar.",
}

const INTRO := "Sekiz yıl önce, 14 Mart 2018 gecesi, Greyfang Lahmacun Sarayı'nın güvenlik kameraları on bir dakika boyunca karardı.\n\nO gece kasiyer Dila Kaya ortadan kayboldu. Gece teknisyeni Hakan Yıldız sistemi kapatmakla suçlandı. Restoran kısa süre sonra kapandı.\n\nHakan, ölene kadar o gece hakkında tek kelime etmedi.\n\nBen Berk Yıldız. Yirmi iki yaşındayım. Hakan benim babamdı.\n\nRestoran yeniden açılıyor ve gece bekçisi arıyorlar. Para lazım. Ama asıl lazım olan, o on bir dakikada ne olduğunu öğrenmek."

const QUESTIONS := [
	{
		"q": "14 Mart gecesi Gece Devriye Modu'nu, binada personel olduğunu bile bile kim başlattı?",
		"options": ["Hakan Yıldız", "Selim Karaca", "Dila Kaya", "Sistem kendiliğinden başladı"],
		"answer": 1,
		"support": ["c_syslog_activate", "c_doc_schedule", "c_dila_note"],
	},
	{
		"q": "Hakan kamera ağını neden on bir dakikalığına kapattı?",
		"options": ["Kasadan para çalmak için", "Selim'in emriyle, kayıtları gizlemek için", "Gece modundaki üniteleri kör edip Dila'yı kaçırmak için", "Bir elektrik arızası yüzünden, kazayla"],
		"answer": 2,
		"support": ["c_form_sensor", "c_tape_hakan_1", "c_syslog_activate"],
	},
	{
		"q": "Kamera arşivini silen ve kayıt saatlerini kaydıran kimdi?",
		"options": ["Hakan Yıldız", "Gülay T.", "Dila Kaya", "Selim Karaca"],
		"answer": 3,
		"support": ["c_syslog_delete", "c_footage_mismatch", "c_email_draft"],
	},
	{
		"q": "Dila'ya ne oldu?",
		"options": ["Animatronikler tarafından öldürüldü", "Hakan'ın yardımıyla kaçtı; adını değiştirip saklandı", "Hâlâ restoranın içinde saklanıyor", "Kimsenin yardımı olmadan kendi isteğiyle şehri terk etti"],
		"answer": 1,
		"support": ["c_tape_hakan_1", "c_postcard", "c_footage_back_door"],
	},
	{
		"q": "Gece Devriye Modu neden tehlikeliydi?",
		"options": ["Elektrik tesisatında yangın riski yaratıyordu", "Üniteler insanları \"izinsiz giriş\" sayıp takip ediyor, yakalıyordu", "Kameraları sürekli bozuyordu", "Tehlikeli değildi; bu bir söylentiydi"],
		"answer": 1,
		"support": ["c_form_hakan_1", "c_test_report", "c_tape_selim_orient"],
	},
]

const ENDINGS := {
	"truth": {
		"title": "SON: GERÇEK",
		"text": "Sabah altıda Berk, topladığı her şeyi bir dosyaya koydu: silinmiş komutlar, bakım formları, babasının kasetleri, Demirkol'un gizli raporu.\n\nBir hafta sonra savcılık Selim Karaca hakkında soruşturma başlattı. Haberlerin birinde bir isim geçti: yurt dışında yaşayan, gerçek adını yıllar sonra ilk kez kullanan bir kadın. Elinde sekiz yıldır sakladığı raporların kopyaları vardı.\n\nDila Kaya, ifadesinin ilk cümlesinde bir teknisyenin adını verdi: Hakan Yıldız. \"O on bir dakika olmasaydı, bugün burada olmazdım.\"\n\nBerk, babasının mezarına bu kez başı dik gitti.\n\nGreyfang hiç açılmadı. Söküm ekibi Altın Grayson'ı depoda bulamadı. Kayıtlara göre o gece kimse onu kapatmamıştı.",
	},
	"partial": {
		"title": "SON: YARIM KALAN",
		"text": "Berk bir şeylerin yanlış olduğunu biliyordu; Selim Karaca'nın bir şeyler sakladığını da. Ama parçalar tam oturmadı.\n\nTopladığı kanıtlar bir dosyaya girdi, dosya bir masaya, masa bir rafa. Soruşturma açılmadı. Hakan'ın adı hâlâ o eski gazete kupüründe, \"teknisyen H.Y.\" olarak duruyor.\n\nBelki bir gün biri o on bir dakikayı yeniden sorar. Belki o gün cevap hazır olur.\n\n(Günlüğü yeniden incele. Bazı kanıtlar birbirini doğruluyor; bazıları ise ilk göründükleri gibi değil.)",
	},
	"wrong": {
		"title": "SON: SESSİZLİK",
		"text": "Berk, en kolay görünen hikâyeye inandı. Belki de babası gerçekten bir şey saklıyordu; belki o gece gerçekten bir suç işlenmişti.\n\nSöküm ekibi sabah geldiğinde ofiste kimseyi bulamadı. Kamera kayıtlarında 05:49 ile 06:00 arasında on bir dakikalık bir boşluk vardı.\n\nYine.\n\n(Kanıtları baştan incele. Herkes söylediği kişi değil; bazı ifadeler eksik bir anı anlatıyor.)",
	},
}


static func clue(id: String) -> Dictionary:
	return CLUES.get(id, {})


static func core_ids() -> Array:
	var out := []
	for id in CLUES.keys():
		if CLUES[id].core:
			out.append(id)
	return out
