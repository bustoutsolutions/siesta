//
//  CommentaryViewController.swift
//  GithubBrowser
//
//  Created by Paul on 2017/9/14.
//  Copyright © 2017 Bust Out Solutions. All rights reserved.
//

import UIKit

class CommentaryViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var popupScroll: UIScrollView!
    @IBOutlet weak var popupPosition: NSLayoutConstraint!
    @IBOutlet weak var commentaryScroll: UIScrollView!
    @IBOutlet weak var commentaryPageControl: UIPageControl!
    @IBOutlet weak var commentaryStackView: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()

        commentaryVisible = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChangedFrame),
            name: .UIKeyboardWillChangeFrame,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showCommentary(notification:)),
            name: .ShowCommentary,
            object: nil)
    }

    static func publishCommentary(_ commentary: String) {
        NotificationCenter.default.post(
            name: .ShowCommentary, object: nil, userInfo: [commentaryKey: commentary])
    }

    private static let commentaryKey = "CommentaryViewController.commentary"

    @objc func showCommentary(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let commentary = userInfo[CommentaryViewController.commentaryKey] as? String
        else {
            return
        }
        showCommentary(commentary)
    }

    func showCommentary(_ commentary: String) {
        let pages = commentary
            .replacingOccurrences(of: "\n( *\n)+", with: "\0", options: .regularExpression, range: nil)
            .split(separator: "\0")
            .map(String.init)

        for existing in commentaryStackView.arrangedSubviews {
            existing.removeFromSuperview()
        }

        for pageHTML in pages {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14)
            label.attributedText = formatCommentary(pageHTML)
            label.numberOfLines = 0
            label.textColor = .black
            commentaryStackView.addArrangedSubview(label)
            [
                label.widthAnchor.constraint(equalTo: commentaryScroll.widthAnchor, multiplier: 1, constant: -commentaryStackView.spacing),
                label.heightAnchor.constraint(lessThanOrEqualTo: commentaryScroll.heightAnchor)
            ].forEach({ $0.isActive = true })
        }
        commentaryStackView.layoutIfNeeded()
        commentaryPageControl.numberOfPages = pages.count
        commentaryScroll.contentOffset = CGPoint.zero

        commentaryVisible = Bool(commentaryVisible)  // reposition after text change
    }

    private var commentaryVisible: Bool {
        get {
            return popupScroll.contentOffset.y > 0
        }
        set(visible) {
            UIView.animate(withDuration: 0.3) {
                self.popupScroll.layoutIfNeeded()

                var newPos = visible
                    ? self.popupScroll.contentSize.height - self.popupScroll.frame.size.height
                    : 0
                if visible && newPos <= 0 {
                    newPos = .infinity
                }
                self.popupScroll.contentOffset = CGPoint(x: 0, y: newPos)
            }
        }
    }

    @IBAction func toggleCommentary() {
        commentaryVisible = !commentaryVisible
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        commentaryPageControl.currentPage = commentaryScroll.currentPageX

        commentaryScroll.alpha =
            popupScroll.contentOffset.y
                / (popupScroll.contentSize.height - popupScroll.frame.size.height)
    }

    @IBAction func pageControlChangedPage() {
        commentaryScroll.currentPageX = commentaryPageControl.currentPage
    }

    @objc private func keyboardChangedFrame(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5) {
            self.popupPosition.constant = self.view.frame.maxY - keyboardFrame.minY
            self.view.layoutIfNeeded()
        }
    }

    private func formatCommentary(_ html: String) -> NSAttributedString? {
        let htmlDocument =
            """
            <html>
              <head>
                <meta charset="UTF-8">
                <style type='text/css'>
                  body { font: 14px sans-serif; }
                </style>
              </head>
              <body>
                  \(html)
              </body>
            </html>
            """
        guard let utf8data = htmlDocument.data(using: String.Encoding.utf8) else {
            return nil
        }
        return try? NSAttributedString(
            data: utf8data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil)

    }
}

extension NSNotification.Name {
    fileprivate static let ShowCommentary = NSNotification.Name("CommentaryViewController.ShowCommentary")
}

/// Scroll view that ignores touches that do not land inside one of its subviews
class PassThroughScrollView: UIScrollView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return super.point(inside: point, with: event)
            && subviews.contains(where:
                { $0.point(inside: convert(point, to: $0), with: event)})
    }
}

extension UIScrollView {
    fileprivate var currentPageX: Int {
        get { return Int(round(contentOffset.x / bounds.size.width)) }
        set {
            setContentOffset(
                CGPoint(x: bounds.size.width * CGFloat(newValue), y: 0),
                animated: true)
        }
    }
}
