import SwiftUI
import Vision
struct ContentView: View {
    @StateObject var viewModel = PoseDetectionViewModel()

    var body: some View {
        ZStack {
            CameraPreviewView(viewModel: viewModel)
            if let points = viewModel.currentPoints {
                PoseOverlayView(points: points, evaluationColor: viewModel.overlayColor)
            }
            VStack {
                Spacer()
                Text(viewModel.feedbackText)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
            }
        }
    }
}
