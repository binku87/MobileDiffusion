//
//  Extension.swift
//  MobileDiffusion
//
//  Created by apple on 9/17/23.
//
import UIKit

protocol ReusableView {
    static var reuseIdentifier: String { get }
}

extension ReusableView {
    static var reuseIdentifier: String {
        return "\(self)"
    }
}

extension UITableViewCell: ReusableView {}

protocol NibLoadable: ReusableView {
    static var nib: UINib { get }
}

extension NibLoadable {
    static var nib: UINib {
        return UINib(nibName: reuseIdentifier, bundle: nil)
    }
}

extension UITableView {
    func registerNibCell<T: NibLoadable>(ofType: T.Type) {
        self.register(T.nib, forCellReuseIdentifier: T.reuseIdentifier)
    }
    
    func dequeueRegisteredCell<T: ReusableView>(oftype: T.Type, at indexPath: IndexPath) -> T {
        let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath)
        return cell as! T //Should be safe to force unwrap since reuse ID is derived from class name
    }
}

extension Notification.Name {
    static let MemoryDidWarning = NSNotification.Name("MemoryDidWarning")
    static let AppWillTerminate = NSNotification.Name("AppWillTerminate")
}

extension NotificationCenter {
    func reinstall(observer: NSObject, name: Notification.Name, selector: Selector) {
        NotificationCenter.default.removeObserver(observer, name: name, object: nil)
        NotificationCenter.default.addObserver(observer, selector: selector, name: name, object: nil)
    }
}
