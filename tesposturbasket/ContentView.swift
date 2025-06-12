import SwiftUI
import Vision

struct ContentView: View {
    @StateObject var viewModel = PoseDetectionViewModel()
    @State private var isRecording = false
    @State private var countdown: Int? = nil
    @State private var selectedImages: [UIImage] = []

    @State private var navigateToResult = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    CameraPreviewView(
                        viewModel: viewModel,
                        isRecording: $isRecording,
                        onImageSaved: { image in
                            // Tambahkan ke galeri internal
                            selectedImages.append(image)

                            // Jika ini frame pertama → langsung pindah ke result view
                            if selectedImages.count == 1 {
                                navigateToResult = true
                            }
                        }
                    )

                        .frame(height: 400)

                    Text(viewModel.feedbackText)
                        .padding()

                    Text(viewModel.ballStatus)
                        .foregroundColor(viewModel.overlayColor)
                        .padding()

                    Button(action: startRecording) {
                        Text(isRecording ? (countdown != nil ? "Countdown: \(countdown!)" : "Merekam...") : "Mulai Rekam")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isRecording ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    .disabled(isRecording)
                }

                // Overlay countdown
                if let count = countdown {
                    Text("\(count)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .transition(.scale)
                }

                // Navigation otomatis setelah gambar tersedia
                NavigationLink(
                    isActive: $navigateToResult,
                    destination: {
                        ResultView(images: selectedImages)
                    },
                    label: {
                        EmptyView()
                    }
                )

                .hidden()

            }
            // Pantau perubahan gambar
            .onChange(of: viewModel.savedBallImages) { newImages in
                if !isRecording, let firstImage = newImages.last {
                    selectedImages = newImages
                    navigateToResult = true
                    print("🟢 Gambar terakhir disimpan: \(firstImage.size)")
                }
            }

        }
    }

    private func startRecording() {
        viewModel.savedBallImages = []
        selectedImages = [] // ← ganti ini, bukan selectedImage
        navigateToResult = false
        countdown = 5
        isRecording = true

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let current = countdown, current > 1 {
                countdown = current - 1
            } else {
                timer.invalidate()
                countdown = nil
                isRecording = false
            }
        }
    }

}
