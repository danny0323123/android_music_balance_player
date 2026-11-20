# jaudiotagger 用反射依 ID3 frame 名稱建立 FrameBody 類別，縮減時不能拿掉
-keep class org.jaudiotagger.** { *; }
# 桌面 Java 的圖片類別在 Android 上不存在，jaudiotagger 只在非 Android 模式用到
-dontwarn java.awt.**
-dontwarn javax.imageio.**
-dontwarn javax.swing.**
-dontwarn java.beans.**
