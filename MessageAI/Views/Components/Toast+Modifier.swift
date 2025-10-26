import SwiftUI

struct ToastModifier<ToastContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let duration: TimeInterval
    @ViewBuilder let toast: () -> ToastContent

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                VStack {
                    toast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 12)
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.3), value: isPresented)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast<ToastContent: View>(
        isPresented: Binding<Bool>,
        duration: TimeInterval = 2.4,
        @ViewBuilder content: @escaping () -> ToastContent
    ) -> some View {
        modifier(ToastModifier(isPresented: isPresented, duration: duration, toast: content))
    }
}
