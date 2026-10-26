import 'package:flutter/material.dart';

class BookingStepperHeader extends StatelessWidget {
  final int currentStep; // 1: Chọn vé, 2: Thông tin, 3: Kiểm tra, 4: Thanh toán
  final ValueChanged<int>? onStepTapped;

  const BookingStepperHeader({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  static const List<String> stepLabels = [
    'Chọn vé',
    'Thông tin',
    'Kiểm tra',
    'Thanh toán',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF070D1E),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSteps = stepLabels.length;
          final stepWidth = constraints.maxWidth / totalSteps;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Connecting background line between step 1 and step 4
              Positioned(
                top: 18,
                left: stepWidth / 2,
                right: stepWidth / 2,
                child: Container(
                  height: 2,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),

              // Active progress fill line
              Positioned(
                top: 18,
                left: stepWidth / 2,
                width: ((constraints.maxWidth - stepWidth) / (totalSteps - 1)) *
                    (currentStep - 1).clamp(0, totalSteps - 1),
                child: Container(
                  height: 2.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFC99A47),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // Steps Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalSteps, (index) {
                  final stepNum = index + 1;
                  final isDone = stepNum < currentStep;
                  final isActive = stepNum == currentStep;

                  return GestureDetector(
                    onTap: () {
                      if (isDone && onStepTapped != null) {
                        onStepTapped!(stepNum);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: stepWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Circle indicator
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isActive
                                  ? const LinearGradient(
                                      colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isActive
                                  ? null
                                  : isDone
                                      ? const Color(0xFF0C1733)
                                      : const Color(0xFF0F172A),
                              border: Border.all(
                                color: isActive
                                    ? Colors.transparent
                                    : isDone
                                        ? const Color(0xFFE6C17A).withOpacity(0.6)
                                        : Colors.white.withOpacity(0.12),
                                width: isActive ? 0 : (isDone ? 1.5 : 1),
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFC99A47).withOpacity(0.55),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : (isDone
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFC99A47).withOpacity(0.2),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null),
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFFE6C17A),
                                      size: 18,
                                    )
                                  : Text(
                                      '$stepNum',
                                      style: TextStyle(
                                        color: isActive
                                            ? const Color(0xFF070D1E)
                                            : (isDone
                                                ? const Color(0xFFE6C17A)
                                                : Colors.white38),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Step Label
                          Text(
                            stepLabels[index],
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : (isDone
                                      ? const Color(0xFFE6C17A)
                                      : Colors.white38),
                              fontSize: 11,
                              fontWeight: isActive || isDone
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
