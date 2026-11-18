# SW2 HID Bridge for iPhone (jailbroken)

نسخة iOS من `SW2HIDBridge.exe` تعمل عبر **Wi-Fi TCP فقط** مع لوحة ESP32-S3
(`192.168.4.1:8231`)، وتضيف أزرار اختصارات قابلة للتعديل لجمل SmileBASIC.

> iPhone لا يستطيع تقليد منفذ USB Serial للوحة، لذلك مسار USB غير موجود هنا.
> المسارات غير المتوفرة أيضاً: الاختصار العام للوحة المفاتيح، أيقونة شريط
> القائمة، وتشغيل عند الدخول. كل شيء آخر (TYPE/PING/STATUS/NET/CONFIG/REPORT/
> KEY/STOP، مdns، الحالة، السجل، التوقيتات) موجود.

## الميزات

- اتصال TCP باللوحة على `192.168.4.1:8231` مع إعادة اتصال تلقائية.
- اكتشاف `_hidbridge._tcp` عبر Bonjour.
- إرسال النص المكتوب أو من الحافظة بصيغة `TYPE` مع التوقيتات القابلة للضبط.
- `STOP` وإيقاف طارئ، `PING`، `STATUS`، `KEY 57` لمسح Caps Lock.
- أوامر الشبكة `NET block on|nintendo|off` وقراءة حالة AP.
- اختيار التخطيط `us/gb` ونمط الإرسال `single/split`.
- **الاختصارات**: افتراضياً ثلاثة أزرار:
  1. `LOAD "TXT:NS2"`
  2. `RUN\nREMOVE NSR,&H60000000,&H3FFFFFFF\nV=START(39380,192,168,31,24)`
  3. التسلسل الكامل بأربعة أسطر.
  يمكن تعديل النص والاسم وإضافة/حذف/ترتيب الاختصارات؛ تُحفظ في `UserDefaults`.

## البناء

المستودع يحتوي `.github/workflows/build-ios.yml`: عند أي دفع إلى `main` يبني
GitHub Actions على `macos-14` ملفاً غير موقّع ويضعه في:

```
dist/SW2HIDBridge-unsigned.ipa
```

يمكن أيضاً بناؤه يدوياً على ماك:

```bash
brew install xcodegen
bash build-ipa.sh
```

## التثبيت على iPhone جيلبريك

1. نزّل `dist/SW2HIDBridge-unsigned.ipa` من المستودع أو من Artifacts في Actions.
2. ثبّته عبر Filza / AppSync Unified (مطلوب لتجاوز توقيع iOS).
3. افتح التطبيق، اضبط المضيف `192.168.4.1` والمنفذ `8231`، ثم اضغط «اتصال».
4. تأكد أن iPhone متصل بشبكة `SWITCH2` أو أن اللوحة متاحة على الشبكة المحلية.

## ملاحظة أمان

`DONE` يعني أن ESP32 أرسل تقارير HID، ولا يثبت أن Switch 2 عرض النص.
لا تُعد إرسال مهمة في حالة `uncertain` تلقائياً.
