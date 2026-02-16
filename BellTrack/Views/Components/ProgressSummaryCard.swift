import SwiftUI

struct ProgressSummaryCard: View {

    let muscleBalance: [MuscleBalanceData]
    let volumeTrend: VolumeTrend?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            // Muscle Balance Section
            VStack(alignment: .leading, spacing: Theme.Space.smp) {
                Text("Muscle Balance")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.brand.textPrimary)

                VStack(spacing: Theme.Space.sm) {
                    ForEach(muscleBalance) { balance in
                        muscleBalanceRow(balance)
                    }
                }
            }

            // Volume Trend Section
            if let trend = volumeTrend {
                Divider()
                    .background(Color.brand.border)

                volumeTrendView(trend)
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surfaceSecondary)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Muscle Balance Row

    private func muscleBalanceRow(_ balance: MuscleBalanceData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(balance.category.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()

                Text("\(Int(balance.percent * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.brand.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brand.surface)
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brand.primary)
                        .frame(width: geometry.size.width * balance.percent, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Volume Trend View

    private func volumeTrendView(_ trend: VolumeTrend) -> some View {
        HStack(spacing: Theme.Space.smp) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Volume Trend")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.brand.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: trend.isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(trend.isPositive ? Color.brand.success : Color.brand.destructive)

                    Text("\(trend.isPositive ? "+" : "")\(String(format: "%.0f", abs(trend.percentChange)))% vs last week")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(trend.isPositive ? Color.brand.success : Color.brand.destructive)
                }
            }

            Spacer()
        }
    }
}
