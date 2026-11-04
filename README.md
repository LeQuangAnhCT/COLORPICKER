# Color Sweep cho grandMA2

Plugin Lua cho grandMA2 3.9.x tai Plugin Pool 20, co menu tao Macro dieu khien, cau hinh va ap dung Color Sweep. Repository van giu plugin Macro Pack cu nhu mot lua chon doc lap, nhung khong can chay no.

## Cai dat

1. Sao luu show va thu voi MA 3D, ngat DMX den den that.
2. Import `ColorSweep_Plugin20.xml` vao **Plugin Pool 20**, voi file Lua tuong ung nam cung thu muc. Sao luu plugin cu truoc neu o 20 da duoc su dung.
3. Chay Plugin 20. Lan dau, plugin tim mot Executor trong tren Page 1, tu `1.201` den `1.240`, va xin xac nhan tao menu. Chu y Programmer se bi xoa va BlindEdit duoc tat sau khi tao menu.
4. Chon `01 CREATE DELAY AND SWEEP MACROS`. Mac dinh tao Macro `1.500` den `1.515`; co the chon dai khac. Neu o da co Macro, plugin hien danh sach va hoi truoc khi thay the toan bo Macro.
5. Chon `02 SETUP GROUPS AND SWEEP`. Khai bao Group, so Executor mau tren Page 99 va so Cue cho tung loai den.
6. Neu nang cap tu menu cu, plugin de nghi tao menu moi tai Executor trong. Menu cu duoc giu nguyen, khong tu dong xoa; menu moi su dung cac muc da duoc sap xep lai.
7. Dua cac Macro dieu khien vao Layout; plugin khong tu thay doi cac nut Layout cu.

## Dieu khien

- Muc 01 tao 6 nut Delay nen, 6 nut thoi gian Sweep va 4 nut huong L-R, R-L, OUT, IN. Khi bam, Macro goi Plugin 20 de cap nhat cac Cue da khai bao sau khi Setup.
- Delay nen la thoi gian cho truoc khi Sweep bat dau. Vi du Delay 1s va Sweep 2s tao dai Delay 1 den 3 giay.
- Huong phu thuoc **thu tu fixture trong Group**, khong doc toa do Layout hay tu xac dinh huong tren/duoi.
- Plugin 20 con tao 10 Macro rieng tai `1.130` den `1.139` va 24 All Preset `0.1` den `0.24`. Hai dai Macro khong duoc trung nhau; cac dai Macro mau da cau hinh cung duoc kiem tra khi Setup.
- Menu dung mot Sequence va Executor moi. Plugin chi tao tai o trong sau khi xac nhan, sau do mo lai menu bang `Goto Executor`. Neu Executor menu bi doi ten hoac xoa, plugin dung va khong ghi de.

## Canh bao

- Setup co the **thay the Macro 130-139 va ghi de Preset 0.1-0.24** sau khi ban xac nhan. Dung xac nhan neu co du lieu can giu.
- Moi lan ap dung Sweep se sua Cue mau da khai bao tren Page 99, dat Cue Fade ve 0 va xoa Programmer. Khong nen chay tren show dang bieu dien; hay sao luu show va kiem tra tren ban sao.
- Cac chuc nang sua Macro mau, Macro ALL, lam moi Preset va Dimmer Dip deu yeu cau xac nhan. Chuc nang Dimmer Dip can thu rieng voi fixture profile va output thuc te truoc khi su dung.
- Plugin khong tu xoa Macro Pack cu, Preset cu, hay thay the cac nut Layout cu. Cac nut cu co the van tham chieu bien khac va khong dieu khien ban plugin moi.
- Khi loi trong luc ghi, mot so doi tuong da tao co the van con. Khong co rollback tu dong. Kiem tra Command Line Feedback va ban sao luu.

## Kiem thu

`tests/sweep_integration_test.lua` su dung `gma` mock de kiem tra menu, va cham Macro, xac nhan ghi de va tinh Delay. Chay bang Lua hoac Fengari tu thu muc repository. Kiem thu mock khong thay the viec kiem tra tren grandMA2 onPC/MA 3D.
