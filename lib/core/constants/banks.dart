class BankItem {
  final String code;
  final String shortName;
  final String fullName;
  final String bin;

  const BankItem({
    required this.code,
    required this.shortName,
    required this.fullName,
    required this.bin,
  });

  String get displayName {
    if (shortName == code) {
      return '$shortName - $fullName';
    }
    return '$shortName ($code) - $fullName';
  }
}

const List<BankItem> vietnameseBanks = [
  BankItem(code: 'VCB', shortName: 'Vietcombank', fullName: 'Ngân hàng TMCP Ngoại thương Việt Nam', bin: '970436'),
  BankItem(code: 'CTG', shortName: 'VietinBank', fullName: 'Ngân hàng TMCP Công thương Việt Nam', bin: '970415'),
  BankItem(code: 'BIDV', shortName: 'BIDV', fullName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', bin: '970418'),
  BankItem(code: 'VBA', shortName: 'Agribank', fullName: 'Ngân hàng Nông nghiệp và PTNT Việt Nam', bin: '970405'),
  BankItem(code: 'TCB', shortName: 'Techcombank', fullName: 'Ngân hàng TMCP Kỹ thương Việt Nam', bin: '970407'),
  BankItem(code: 'MB', shortName: 'MB Bank', fullName: 'Ngân hàng TMCP Quân đội', bin: '970422'),
  BankItem(code: 'ACB', shortName: 'ACB', fullName: 'Ngân hàng TMCP Á Châu', bin: '970416'),
  BankItem(code: 'VPB', shortName: 'VPBank', fullName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng', bin: '970432'),
  BankItem(code: 'TPB', shortName: 'TPBank', fullName: 'Ngân hàng TMCP Tiên Phong', bin: '970423'),
  BankItem(code: 'STB', shortName: 'Sacombank', fullName: 'Ngân hàng TMCP Sài Gòn Thương Tín', bin: '970403'),
  BankItem(code: 'HDB', shortName: 'HDBank', fullName: 'Ngân hàng TMCP Phát triển TP.HCM', bin: '970437'),
  BankItem(code: 'VIB', shortName: 'VIB', fullName: 'Ngân hàng TMCP Quốc tế Việt Nam', bin: '970441'),
  BankItem(code: 'SHB', shortName: 'SHB', fullName: 'Ngân hàng TMCP Sài Gòn - Hà Nội', bin: '970443'),
  BankItem(code: 'SSB', shortName: 'SeABank', fullName: 'Ngân hàng TMCP Đông Nam Á', bin: '970468'),
  BankItem(code: 'OCB', shortName: 'OCB', fullName: 'Ngân hàng TMCP Phương Đông', bin: '970448'),
  BankItem(code: 'MSB', shortName: 'MSB', fullName: 'Ngân hàng TMCP Hàng Hải Việt Nam', bin: '970426'),
  BankItem(code: 'LPB', shortName: 'LPBank', fullName: 'Ngân hàng TMCP Lộc Phát Việt Nam', bin: '970449'),
  BankItem(code: 'PVCB', shortName: 'PVcomBank', fullName: 'Ngân hàng TMCP Đại Chúng Việt Nam', bin: '970412'),
  BankItem(code: 'BAB', shortName: 'Bac A Bank', fullName: 'Ngân hàng TMCP Bắc Á', bin: '970409'),
  BankItem(code: 'NAB', shortName: 'Nam A Bank', fullName: 'Ngân hàng TMCP Nam Á', bin: '970428'),
  BankItem(code: 'KLB', shortName: 'Kienlongbank', fullName: 'Ngân hàng TMCP Kiên Long', bin: '970452'),
  BankItem(code: 'BVB', shortName: 'BVBank', fullName: 'Ngân hàng TMCP Bản Việt', bin: '970454'),
  BankItem(code: 'BAOVIET', shortName: 'BaoViet Bank', fullName: 'Ngân hàng TMCP Bảo Việt', bin: '970438'),
  BankItem(code: 'SGB', shortName: 'Saigonbank', fullName: 'Ngân hàng TMCP Sài Gòn Công Thương', bin: '970400'),
  BankItem(code: 'VBB', shortName: 'VietBank', fullName: 'Ngân hàng TMCP Việt Nam Thương Tín', bin: '970433'),
  BankItem(code: 'NCB', shortName: 'NCB', fullName: 'Ngân hàng TMCP Quốc Dân', bin: '970419'),
  BankItem(code: 'SHBVN', shortName: 'Shinhan Bank', fullName: 'Ngân hàng TNHH MTV Shinhan Việt Nam', bin: '970424'),
  BankItem(code: 'WRB', shortName: 'Woori Bank', fullName: 'Ngân hàng TNHH MTV Woori Việt Nam', bin: '970457'),
  BankItem(code: 'PBVN', shortName: 'Public Bank', fullName: 'Ngân hàng TNHH MTV Public Việt Nam', bin: '970439'),
  BankItem(code: 'HLBVN', shortName: 'Hong Leong Bank', fullName: 'Ngân hàng TNHH MTV Hong Leong Việt Nam', bin: '970442'),
  BankItem(code: 'HSBC', shortName: 'HSBC', fullName: 'Ngân hàng TNHH MTV HSBC (Việt Nam)', bin: '458761'),
  BankItem(code: 'SCBVL', shortName: 'Standard Chartered', fullName: 'Ngân hàng TNHH MTV Standard Chartered Việt Nam', bin: '970410'),
  BankItem(code: 'CAKE', shortName: 'Cake by VPBank', fullName: 'Ngân hàng số Cake by VPBank', bin: '546034'),
  BankItem(code: 'TIMO', shortName: 'Timo', fullName: 'Ngân hàng số Timo by BVBank', bin: '963388'),
  BankItem(code: 'VTLMONEY', shortName: 'Viettel Money', fullName: 'Tổng Công ty Dịch vụ Số Viettel', bin: '971005'),
  BankItem(code: 'VNPTMONEY', shortName: 'VNPT Money', fullName: 'Tập đoàn Bưu chính Viễn thông Việt Nam', bin: '971011'),
];
