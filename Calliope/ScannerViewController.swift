import UIKit
import SnapKit

final class ScannerViewController: BaseViewController {

    private let viewImage = UIImageView()
    private let labelText = UILabel()
    private let viewMatrix = MatrixView()
    private let buttonPair = UIButton()

    private var process: BluetoothScan?

    private var discoveries: [BluetoothDiscovery] = []
    private var friendly: String? = nil
    private var action: (()->())? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        unowned let me = self

        navigationItem.title = "scanner.title".localized
        view.backgroundColor = Styles.colorWhite

        let buttonCancel = createCancelButton()
        buttonCancel.addAction(for: .touchUpInside, actionCancel)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView:buttonCancel)

        let buttonHelp = createHelpButton()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView:buttonHelp)

        viewImage.animationImages = [
            UIImage.loadImage(named:"AnimPressToPair/a"),
            UIImage.loadImage(named:"AnimPressToPair/b"),
            UIImage.loadImage(named:"AnimPressToPair/c"),
            UIImage.loadImage(named:"AnimPressToPair/b"),
        ]
        viewImage.animationDuration = 2
        viewImage.animationRepeatCount = -1
        viewImage.contentMode = .scaleAspectFit
        view.addSubview(viewImage)
        viewImage.startAnimating()

        labelText.text = "scanner.text".localized
        labelText.numberOfLines = 0
        labelText.font = Styles.defaultFont(size: range(15...35))
        labelText.textColor = Styles.colorGray
        view.addSubview(labelText)

        viewMatrix.isOpaque = false
        viewMatrix.onChange = { matrix in
            me.friendly = Microbit.matrix2friendly(matrix)
            me.updateMatch()
        }
        view.addSubview(viewMatrix)

        buttonPair.setTitle("scanner.button".localized, for: .normal)
        buttonPair.setTitleColor(Styles.colorWhite, for: .normal)
        buttonPair.titleLabel?.font = Styles.defaultFont(size: range(18...42))
        buttonPair.backgroundColor = Styles.colorYellow
        buttonPair.addAction(for: .touchUpInside) { _ in
            if let action = me.action {
                action()
            }
        }
        buttonPair.isEnabled = false
        buttonPair.alpha = 0.2
        view.addSubview(buttonPair)

        layout()

        let scanner = BluetoothScan({ map in
//            for discovery in map.values {
//                let name = discovery.name
//                let identifier = discovery.peripheral.identifier
//                let advertisementData = discovery.advertisementData
//                LOG(" - [\(name ?? "")] [\(identifier)]: \(advertisementData)")
//            }
            me.discoveries = Array(map.values
            .filter({ discovery -> Bool in
                return discovery.name?.hasPrefix("BBC micro:bit [") ?? false
                    || discovery.name?.hasPrefix("Calliope mini [") ?? false
            }))
//            LOG("found \(map.count) devices, \(me.discoveries.count) relevant")
            me.updateMatch()
        })
        process = scanner
    }

    func layout() {
        let superview = view!

        let marginX = range(20...40)
        let marginY = range(20...40)
        let spacingY = range(20...40)
        let height = range(70...170)

        guard let image = viewImage.animationImages?.first else { return }
        let imageRatio = image.size.height/image.size.width

        viewImage.snp.makeConstraints { make in
            make.top.equalTo(superview).offset(marginY)
            make.centerX.equalTo(labelText)
            make.width.equalTo(labelText).multipliedBy(0.5)
            make.height.equalTo(viewImage.snp.width).multipliedBy(imageRatio)
        }

        labelText.snp.makeConstraints { make in
            make.top.equalTo(viewImage.snp.bottom).offset(spacingY)
            make.left.equalTo(superview).offset(marginX)
            make.right.equalTo(superview).offset(-marginX)
        }

        viewMatrix.snp.makeConstraints { make in
            make.top.equalTo(labelText.snp.bottom).offset(spacingY)
            make.left.right.equalTo(labelText)
        }

        buttonPair.snp.makeConstraints { make in
            make.top.equalTo(viewMatrix.snp.bottom).offset(spacingY)
            make.left.right.bottom.equalTo(superview)
            make.height.equalTo(height)
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let scanner = process {
            scanner.start()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let scanner = process {
            scanner.stop()
        }
    }

    func actionCancel(button: UIButton) {
        if let scanner = process {
            scanner.stop()
        }
        dismiss(animated: true)
    }

    func find() -> BluetoothDiscovery? {
        if let friendly = friendly {
            let matches = discoveries.filter { discovery -> Bool in
                let microbit = "BBC micro:bit [\(friendly)]"
                let caliope = "Calliope mini [\(friendly)]"
                return discovery.name == microbit
                    || discovery.name == caliope
            }
            if matches.count == 1 {
                return matches.first
            }
        }
        return nil
    }

    func updateMatch() {
        unowned let me = self

        if let discovery = find() {
            buttonPair.isEnabled = true
            buttonPair.alpha = 1.0

            action = {
                let device = Device(name: discovery.name!, identifier: discovery.peripheral.identifier)

                let vc = ConnectViewConroller()
                vc.device = device
                vc.buttonPressAction = { state in

                    switch(state) {
                    case .progress:
                        // abort
                        if let scanner = me.process {
                            scanner.start()
                        }
                    case .success:
                        Device.current = device
                        me.dismiss(animated: true)
                    case .error:
                        if let scanner = me.process {
                            scanner.start()
                        }
                    }

                }
                let nc = UINavigationController(rootViewController: vc)
                nc.modalTransitionStyle = .crossDissolve
                me.present(nc, animated: true)
            }
        } else {
            buttonPair.isEnabled = false
            buttonPair.alpha = 0.2
        }
    }


}
