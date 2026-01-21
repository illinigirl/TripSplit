//
//  ImagePickerHelper.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI
import PhotosUI

// MARK: - Image Picker Sheet
struct ImagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onImageSelected: (UIImage) -> Void
    
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    
    var body: some View {
        NavigationStack {
            List {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(Color.oceanBlue)
                            .frame(width: 30)
                        Text("Take Photo")
                    }
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(Color.sunsetOrange)
                            .frame(width: 30)
                        Text("Choose from Library")
                    }
                }
            }
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    onImageSelected(image)
                    dismiss()
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoPicker { image in
                    onImageSelected(image)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Photo Picker (from library)
struct PhotoPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.onImageSelected(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Helper to compress images
extension UIImage {
    func compressedForReceipt() -> Data? {
        // Resize if too large
        let maxDimension: CGFloat = 1500
        var image = self
        
        if size.width > maxDimension || size.height > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            image = UIGraphicsGetImageFromCurrentImageContext() ?? self
            UIGraphicsEndImageContext()
        }
        
        // Compress to JPEG with 0.7 quality
        return image.jpegData(compressionQuality: 0.7)
    }
}
