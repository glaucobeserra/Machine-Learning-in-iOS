import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var photoLibraryButton: UIButton!
    @IBOutlet var resultsView: UIView!
    @IBOutlet var resultsLabel: UILabel!
    @IBOutlet var resultsConstraint: NSLayoutConstraint!
    
    
    // MARK: - Properties
    var firstTime = true
    
    lazy var classificationRequest: VNCoreMLRequest = {
        let visionModel = try! VNCoreMLModel(for: HealthySnacks().model)
        let request = VNCoreMLRequest(model: visionModel) { [unowned self] request, _ in
            self.processObservations(for: request)
        }
        request.imageCropAndScaleOption = .centerCrop
        return request
    }()
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        resultsView.alpha = 0
        resultsLabel.text = "choose or take a photo"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Show the "choose or take a photo" hint when the app is opened.
        if firstTime {
            showResultsView(delay: 0.5)
            firstTime = false
        }
    }
    
    // MARK: - Actions
    @IBAction func takePicture() {
        presentPhotoPicker(sourceType: .camera)
    }
    
    @IBAction func choosePhoto() {
        presentPhotoPicker(sourceType: .photoLibrary)
    }
    
    // MARK: - Methods
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
        hideResultsView()
    }
    
    func showResultsView(delay: TimeInterval = 0.1) {
        resultsConstraint.constant = 100
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.5,
                       delay: delay,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.6,
                       options: .beginFromCurrentState,
                       animations: {
                        self.resultsView.alpha = 1
                        self.resultsConstraint.constant = -10
                        self.view.layoutIfNeeded()
        },
                       completion: nil)
    }
    
    func hideResultsView() {
        UIView.animate(withDuration: 0.3) {
            self.resultsView.alpha = 0
        }
    }
    
    func classify(image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let ciImage = CIImage(image: image) else { return }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(ciImage: ciImage,
                                                orientation: orientation)
            try? handler.perform([self.classificationRequest])
        }
    }
    
    func processObservations(for request: VNRequest) {
        DispatchQueue.main.async {
            guard let result = request.results?.first as? VNClassificationObservation else { return }
            self.resultsLabel.text =
                result.confidence > 0.8
                ? {
                    let formatter = NumberFormatter()
                    formatter.maximumFractionDigits = 1
                    let calculatedResult = result.confidence * 100
                    guard let confidencePercentage = formatter.string(from: NSNumber(value: calculatedResult)) else {
                        return "Ops. 100% chance of an error occurring 🤪"
                    }
                    return "\(result.identifier) \(confidencePercentage)%"
                    } ()
                : "Not sure!"
            
            
            self.showResultsView()
        }
    }
}

// MARK: - UIimagePickerControllerDelegate and UINavigationControllerDelegate extensions
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        let image = info[.originalImage] as! UIImage
        imageView.image = image
        
        classify(image: image)
    }
}
