import SwiftUI

/// 进度条组件
/// 用于显示进度百分比
struct ImportProgressBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .cornerRadius(10)
                
                Rectangle()
                    .fill(Color.blue)
                    .cornerRadius(10)
                    .frame(width: max(0, min(CGFloat(value) * geometry.size.width, geometry.size.width)))
            }
        }
        .frame(height: 10)
    }
}

#Preview {
    Text("ProgressBar Component")
        .padding()
}
