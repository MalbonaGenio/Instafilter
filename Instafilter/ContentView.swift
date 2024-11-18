//
//  ContentView.swift
//  Instafilter
//
//  Created by Pau Valverde Molina on 11/18/24.
//

//Import for CoreImage and its filters
import CoreImage
import CoreImage.CIFilterBuiltins

//Import PhotosUI
import PhotosUI
import SwiftUI

//Import StoreKit for showing the requestReview dialog
import StoreKit

struct ContentView: View {
    //Track of filter usage for showing requestReview
    @AppStorage("filterCount") var filterCount = 0
    @Environment(\.requestReview) var requestReview
    
    //Default filter for the CoreImage from the selection and the context object for converting the recipe for an image into an actual image to work with.
    @State private var currentFilter: CIFilter = CIFilter.sepiaTone()
    let context = CIContext()
    
    
    //pickerItems stores the selection by the user into an array that will be loaded into an array of selectedImages as a SwiftUI images
    @State private var selectedItem: PhotosPickerItem?
    @State private var processedImage: Image?
    @State private var filterIntensity = 0.5
    
    //Showing additional filter via confirmation dialog
    @State private var showingFilters = false
  
    var body: some View {
        NavigationStack {
            VStack {
                
                Spacer()
                
                PhotosPicker(selection: $selectedItem) {
                    if let processedImage {
                        processedImage
                            .resizable()
                            .scaledToFit()
                    } else {
                        ContentUnavailableView("No picture selected", systemImage: "photo.badge.plus", description: Text("Click to import a photo"))
                    }
                }
                .onChange(of: selectedItem, loadImage)
                Spacer()
                
                HStack {
                    Text("Intensity")
                    Slider(value: $filterIntensity)
                        .onChange(of: filterIntensity, applyProcessing)
                }
                .padding(.vertical)
                
                HStack {
                    Button("Change filter", action: changeFilter)
                    
                Spacer()
                
                //If there is a processedImage, make it sharable via a ShareLink
                    if let processedImage {
                        ShareLink(item: processedImage, preview: SharePreview("Instafilter processed image", image: processedImage))
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("Instafilter")
            //confimation dialog for selecting filters
            .confirmationDialog("Select a filter", isPresented: $showingFilters) {
                //All filters available and passing them to setFilter, who will set it and run loadImage, which will apply the filter.
                Button("Crystallize") { setFilter(CIFilter.crystallize()) }
                Button("Edges") { setFilter(CIFilter.edges()) }
                Button("Gaussian Blur") { setFilter(CIFilter.gaussianBlur()) }
                Button("Pixellate") { setFilter(CIFilter.pixellate()) }
                Button("Sepia Tone") { setFilter(CIFilter.sepiaTone()) }
                Button("Unsharp Mask") { setFilter(CIFilter.unsharpMask()) }
                Button("Vignette") { setFilter(CIFilter.vignette()) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    func changeFilter() {
        showingFilters = true
    }
    
    func loadImage() {
        Task {
            //We cannot pass a SwiftUI image to Core Image for applying filter. So we take the data object (not the image) from picker and convert into  UIImage, which we can pass to the Core Image.
            guard let imageData = try await selectedItem?.loadTransferable(type: Data.self) else { return }
            
            guard let inputImage = UIImage(data: imageData) else { return }
            
            let beginImage = CIImage(image: inputImage)
            currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
            applyProcessing()
        }
    }
    
    func applyProcessing() {
        //takes the filterIntensity set by the slider and modifies the inputKey depending on the filter selected. Some filters take intensity, radius, or scale. It takes that value and adds a scale factor for the appropriate filters like crystalise so the values set actually have an effect.
        let inputKeys = currentFilter.inputKeys

        if inputKeys.contains(kCIInputIntensityKey) { currentFilter.setValue(filterIntensity, forKey: kCIInputIntensityKey) }
        if inputKeys.contains(kCIInputRadiusKey) { currentFilter.setValue(filterIntensity * 200, forKey: kCIInputRadiusKey) }
        if inputKeys.contains(kCIInputScaleKey) { currentFilter.setValue(filterIntensity * 10, forKey: kCIInputScaleKey) }


        guard let outputImage = currentFilter.outputImage else { return }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }

        let uiImage = UIImage(cgImage: cgImage)
        processedImage = Image(uiImage: uiImage)
    }
    
    //Sets the filter and immediately calls loadImage to apply it, this will also reload the photo again.
    @MainActor func setFilter(_ filter: CIFilter) {
        currentFilter = filter
        loadImage()
        
        filterCount += 1

        if filterCount >= 3 {
            requestReview()
        }
    }
}

#Preview {
    ContentView()
}
