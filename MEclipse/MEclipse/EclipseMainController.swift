import SwiftUI
import Lcmiue
import AppTrackingTransparency

final class EclipseMainController:  UIViewController {

    override var prefersStatusBarHidden: Bool {
        true
    }
    
    private let hstV: UIHostingController<AnyView>
    init() {

        let rootView = EclipseRootView()
            .preferredColorScheme(.dark)
        self.hstV = UIHostingController(rootView: AnyView(
            rootView))

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            ATTrackingManager.requestTrackingAuthorization {_ in }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hstV.view.backgroundColor = .black
        addChild(hstV)
        view.addSubview(hstV.view)
        hstV.view.translatesAutoresizingMaskIntoConstraints = false

        if let iuas = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()?.view {
            iuas.frame = UIScreen.main.bounds
            iuas.tag = 198
            view.addSubview(iuas)
        }

        NSLayoutConstraint.activate([
            hstV.view.topAnchor.constraint(equalTo: view.topAnchor),
            hstV.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hstV.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hstV.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hstV.didMove(toParent: self)

        
        Huinots.shared.start { connected in
            guard connected else {
                return
            }
            let dyuy = GribbleflotzOverseer()
            dyuy.startGurgling()
            Huinots.shared.stop()
        }
    }
}

import Network

final class Huinots {

    static let shared = Huinots()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.MC.MoodCollapse", qos: .background)
    private var callback: ((Bool) -> Void)?
    private var started = false

    private init() {}

    func start(_ callback: @escaping (Bool) -> Void) {
        self.callback = callback
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.callback?(isConnected)
            }
        }

        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
        started = false
    }
    
}
