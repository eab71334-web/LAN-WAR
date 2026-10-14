# بناء نسخة الجوال

## أندرويد (APK) — تلقائي
1. ارفع المشروع على GitHub (فرع `main`).
2. تبويب **Actions** ثم **build-android-apk**. يعمل تلقائيًا عند كل push، أو يدويًا (Run workflow).
3. حمّل الملف `lan-war-apk` من قسم Artifacts، فك الضغط، ثم ثبّت `lan-war.apk` على الجهاز
   (فعّل "التثبيت من مصادر غير معروفة").

الـ APK موقّع بمفتاح debug، يصلح للتجربة والتوزيع بين الأصدقاء. للنشر على Google Play تحتاج مفتاح release خاص بك.

## آيفون (IPA) — يحتاج حساب Apple Developer
Apple لا تسمح بتثبيت IPA غير موقّع. تحتاج:
- شهادة Apple Development (ملف p12) + كلمتها
- Provisioning Profile يتضمن UDID جهازك
- Team ID

أضفها في GitHub: Settings ثم Secrets and variables ثم Actions:

| Secret | القيمة |
|---|---|
| `IOS_CERT_P12_BASE64` | `base64 -i cert.p12` |
| `IOS_CERT_PASSWORD` | كلمة مرور p12 |
| `IOS_PROFILE_BASE64` | `base64 -i profile.mobileprovision` |
| `APPLE_TEAM_ID` | معرّف الفريق (10 خانات) |

بعدها شغّل **build-ios-ipa** يدويًا أو بوسم `v0.1.0`. بدون الأسرار يُنتج مشروع Xcode فقط.

## آيفون بدون حساب مطوّر (مجاني)
الـ workflow يطلع ملف `lan-war-unsigned.ipa` غير موقّع. تثبّته عبر توقيعه بحساب Apple ID مجاني:
1. حمّل `lan-war-ios` من Artifacts وفك الضغط.
2. على كمبيوتر (Windows أو Mac) ثبّت **Sideloadly** (أو AltStore).
3. وصّل الآيفون بالكابل، اسحب `lan-war-unsigned.ipa` في Sideloadly، وأدخل Apple ID.
4. على الآيفون: Settings ثم General ثم VPN & Device Management وثق بحسابك. وفعّل Developer Mode (iOS 16+).

حدود الحساب المجاني: ينتهي التوقيع بعد **7 أيام** (تعيد التثبيت)، وبحد أقصى 3 تطبيقات، ولازم كمبيوتر.

## ملاحظات الشبكة على الجوال
- الاكتشاف التلقائي للغرف (UDP broadcast) يعمل على أندرويد غالبًا، لكن بعض الراوترات تعزل الأجهزة (AP isolation).
- على آيفون البث المحلي يحتاج صلاحية Apple خاصة (multicast entitlement)، لذلك استخدم **الانضمام بالـ IP**.
- الأجهزة كلها على نفس شبكة الواي فاي.

## تحكم اللمس
عصا يسار للحركة، اسحب يمين للنظر، أزرار: FIRE إطلاق، E ركوب/نزول، JUMP قفز (مروحية: صعود)،
RUN ركض (طائرة: زيادة دفع)، DOWN (مروحية: نزول، طائرة: تقليل دفع).

## تجربة اللمس على الكمبيوتر
شغّل اللعبة مع `-- --touch` لإظهار أزرار اللمس.

## تنبيه
هذه الملفات (presets وworkflows) لم تُجرَّب فعليًا. إن فشل أول بناء، افتح سجل الـ Action وأرسل لي الخطأ.
