class Referral {
  final int id;
  final int referrerId;
  final int referredId;
  final String referredName;
  final bool rewardClaimed;
  final DateTime createdAt;

  const Referral({
    required this.id,
    required this.referrerId,
    required this.referredId,
    required this.referredName,
    required this.rewardClaimed,
    required this.createdAt,
  });

  factory Referral.fromMap(Map<String, dynamic> m) => Referral(
        id: m['id'] as int,
        referrerId: m['referrerId'] as int,
        referredId: m['referredId'] as int,
        referredName: m['referredName'] ?? '—',
        rewardClaimed: m['rewardClaimed'] == true || m['rewardClaimed'] == 1,
        createdAt: m['createdAt'] != null
            ? DateTime.tryParse(m['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'referrerId': referrerId,
        'referredId': referredId,
        'referredName': referredName,
        'rewardClaimed': rewardClaimed ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };
}

class ReferralStats {
  final String referralCode;
  final int totalReferrals;
  final int claimedRewards;
  final int pendingRewards;

  const ReferralStats({
    required this.referralCode,
    required this.totalReferrals,
    required this.claimedRewards,
    required this.pendingRewards,
  });

  factory ReferralStats.fromMap(Map<String, dynamic> m) => ReferralStats(
        referralCode: m['referralCode'] ?? '',
        totalReferrals: m['totalReferrals'] ?? 0,
        claimedRewards: m['claimedRewards'] ?? 0,
        pendingRewards: m['pendingRewards'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'referralCode': referralCode,
        'totalReferrals': totalReferrals,
        'claimedRewards': claimedRewards,
        'pendingRewards': pendingRewards,
      };
}
