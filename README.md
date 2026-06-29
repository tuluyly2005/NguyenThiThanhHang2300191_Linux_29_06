<div align="center">

# Bài cuối kỳ Linux ngày 29/06

**Lời giải bài cuối kỳ**

| Họ và tên | Mã sinh viên |
| --- | --- |
| Nguyễn Thị Thanh Hằng | 2300191 |

</div>

## Cấu trúc thư mục

```text
.
├── README.md
├── assets/
│   ├── code-bai-cuoi-ky-hang.png
│   └── diagram-bai-cuoi-ky-hang.png
├── diagrams/
│   └── bai_cuoi_ky_hang_flow.puml
├── scripts/
│   └── bai_cuoi_ky_hang.sh
└── tests/
    └── run_tests.sh
```

## Sơ đồ xử lý

![Sơ đồ xử lý bài cuối kỳ](assets/diagram-bai-cuoi-ky-hang.png)

## Nội dung bài cuối kỳ

Script `scripts/bai_cuoi_ky_hang.sh` thực hiện lần lượt 10 câu của đề:

| Câu | Chức năng |
| --- | --- |
| 1 | Chia đĩa thành các phân vùng `/`, `/var`, `/usr`, `swap`, `/home`. Sơ đồ đề nghị là `/` 20 GB, `/var` 6 GB, `/usr` 10 GB, `swap` 2 GB, `/home` dùng phần còn lại. |
| 2 | Xem bảng routing bằng `route -n` và `ip route`, lưu kết quả vào `/root/routing`, sau đó in default gateway và địa chỉ đường mạng. |
| 3 | Tìm tập tin lệnh `ping`, rồi kiểm tra kết nối đến `172.29.8.2` và `172.29.8.10`. |
| 4 | Xóa default gateway bằng lệnh `route`, ping lại hai địa chỉ đã cho, thêm lại default gateway và ping so sánh. |
| 5 | Xóa địa chỉ đường mạng trực tiếp bằng lệnh `route`, ping lại hai địa chỉ đã cho, thêm lại địa chỉ đường mạng và ping so sánh. |
| 6 | Lần lượt đổi tên máy bằng `hostname`, `hostnamectl` và ghi `/etc/hostname`; tên cuối cùng là `hang-2300191`. |
| 7 | Lần lượt đổi địa chỉ IP bằng `ip addr`, `ifconfig` và `nmcli` nếu hệ thống có các lệnh tương ứng. |
| 8 | Thiết lập địa chỉ IP tĩnh `192.168.10.91/24`, lưu bảng routing trước và sau khi đổi IP để so sánh sau khi khởi động lại. Số `91` được lấy theo hai số cuối mã sinh viên vì đề không cung cấp số thứ tự máy riêng. |
| 9 | Kiểm tra gói và dịch vụ SSH; nếu chưa có thì cài `openssh-server` từ file `OpenSSH-server.version.rpm`, hoặc dùng `dnf`/`yum` nếu có sẵn kho cài đặt. |
| 10 | Cấu hình DHCP server cấp phát IP động trong khoảng `192.168.10.100` đến `192.168.10.130` cho mạng `192.168.10.0/24`. Khoảng cuối dùng `192.168.10.130` để cùng lớp mạng với địa chỉ IP đã thiết lập ở câu 8. |

## Ảnh chụp mã nguồn

![Ảnh chụp mã nguồn bài cuối kỳ](assets/code-bai-cuoi-ky-hang.png)

## Cách chạy

Chạy script trong máy ảo bài thi bằng quyền `root`:

```bash
chmod +x scripts/bai_cuoi_ky_hang.sh
sudo bash scripts/bai_cuoi_ky_hang.sh
```

Các thao tác có thể làm mất kết nối mạng hoặc ghi lại cấu hình hệ thống cần bật biến xác nhận riêng:

```bash
sudo DISK=/dev/sdb CONFIRM_PARTITION=yes bash scripts/bai_cuoi_ky_hang.sh
sudo CONFIRM_ROUTE_CHANGE=yes bash scripts/bai_cuoi_ky_hang.sh
sudo CONFIRM_HOSTNAME_CHANGE=yes bash scripts/bai_cuoi_ky_hang.sh
sudo IFACE=ens33 CONFIRM_IP_CHANGE=yes bash scripts/bai_cuoi_ky_hang.sh
sudo IFACE=ens33 CONFIRM_STATIC_IP=yes MACHINE_NO=91 bash scripts/bai_cuoi_ky_hang.sh
sudo IFACE=ens33 CONFIRM_DHCP_CONFIG=yes bash scripts/bai_cuoi_ky_hang.sh
```

Sau khi đặt IP tĩnh và khởi động lại máy, kiểm tra lại bảng routing:

```bash
ip route
route -n
```

Khi IP đã chuyển sang lớp mạng `192.168.10.0/24`, bảng routing sẽ có đường mạng trực tiếp `192.168.10.0/24` trên card mạng đang dùng. Nếu đặt gateway `192.168.10.1`, bảng routing cũng có default gateway trỏ về `192.168.10.1`.

## Kiểm thử

```bash
bash tests/run_tests.sh
```

Kiểm thử kiểm tra cú pháp Bash và sự tồn tại của các tệp chính trong bài.
