//
//  StaticTableViewRow.swift
//  ownCloud
//
//  Created by Felix Schwarz on 08.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit

typealias StaticTableViewRowAction = (_ staticRow : StaticTableViewRow, _ sender: Any?) -> Void
typealias StaticTableViewRowTextAction = (_ staticRow : StaticTableViewRow, _ sender: Any?, _ type: StaticTableViewRowActionType) -> Void
typealias StaticTableViewRowEventHandler = (_ staticRow : StaticTableViewRow, _ event : StaticTableViewEvent) -> Void

enum StaticTableViewRowButtonStyle {
	case plain
	case plainNonOpaque
	case proceed
	case destructive
	case custom(textColor: UIColor?, selectedTextColor: UIColor?, backgroundColor: UIColor?, selectedBackgroundColor: UIColor?)
}

enum StaticTableViewRowType {
	case row
	case subtitleRow
	case valueRow
	case radio
	case toggle
	case text
	case secureText
	case label
	case switchButton
	case button
	case datePicker
	case slider
}

enum StaticTableViewRowActionType {
	case changed
	case didBegin
	case didEnd
}

class StaticTableViewRow : NSObject, UITextFieldDelegate {

	public weak var section : StaticTableViewSection?

	public var identifier : String?
	public var groupIdentifier : String?
	public var type : StaticTableViewRowType

	public var value : Any? {
		didSet {
			if updateViewFromValue != nil {
				updateViewFromValue!(self)
			}
		}
	}

	private var updateViewFromValue : ((_ row: StaticTableViewRow) -> Void)?
	private var updateViewAppearance : ((_ row: StaticTableViewRow) -> Void)?

	public var cell : UITableViewCell?

	public var selectable : Bool = true

	public var enabled : Bool = true {
		didSet {
			if updateViewAppearance != nil {
				updateViewAppearance!(self)
			}
		}
	}

	public var action : StaticTableViewRowAction?
	public var textFieldAction : StaticTableViewRowTextAction?
	public var eventHandler : StaticTableViewRowEventHandler?

	public var viewController: StaticTableViewController? {
		return section?.viewController
	}

	private var themeApplierToken : ThemeApplierToken?

	public var index : Int? {
		return section?.rows.index(of: self)
	}

	public var indexPath : IndexPath? {
		if let rowIndex = self.index, let sectionIndex = section?.index {
			return IndexPath(row: rowIndex, section: sectionIndex)
		}

		return nil
	}

	public var attached : Bool {
		return self.index != nil
	}

	var representedObject : Any?

	public var additionalAccessoryView : UIView?

	override init() {
		type = .row
		super.init()
	}

	convenience init(rowWithAction: StaticTableViewRowAction?, title: String, subtitle: String? = nil, image: UIImage? = nil, imageWidth: CGFloat? = nil, imageTintColorKey : String = "labelColor", alignment: NSTextAlignment = .left, accessoryType: UITableViewCell.AccessoryType = .none, identifier : String? = nil, accessoryView: UIView? = nil) {
		self.init()
		type = .row

		var image = image
		if image != nil, imageWidth != nil {
			image = image?.paddedTo(width: imageWidth)
		}

		self.identifier = identifier
		var cellStyle = UITableViewCell.CellStyle.default
		if subtitle != nil {
			cellStyle = UITableViewCell.CellStyle.subtitle
		}

		self.cell = ThemeTableViewCell(withLabelColorUpdates: true, style: cellStyle, reuseIdentifier: nil)
		if subtitle != nil {
			self.cell?.detailTextLabel?.text = subtitle
			self.cell?.detailTextLabel?.numberOfLines = 0
		}
		self.cell?.textLabel?.text = title
		self.cell?.textLabel?.textAlignment = alignment
		self.cell?.accessoryType = accessoryType
		self.cell?.imageView?.image = image
		if accessoryView != nil {
			self.cell?.accessoryView = accessoryView
		}

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		themeApplierToken = Theme.shared.add(applier: { [weak self] (_, themeCollection, _) in
			self?.cell?.imageView?.tintColor = themeCollection.tableRowColors.value(forKeyPath: imageTintColorKey) as? UIColor
			self?.cell?.accessoryView?.tintColor = themeCollection.tableRowColors.labelColor
			})

		self.cell?.accessibilityIdentifier = identifier

		if rowWithAction != nil {
			self.action = rowWithAction
		} else {
			self.cell?.selectionStyle = .none
		}
	}

	convenience init(rowWithAction: StaticTableViewRowAction?, title: String, alignment: NSTextAlignment = .left, accessoryView: UIView? = nil, identifier : String? = nil) {
		self.init()
		type = .row

		self.identifier = identifier

		self.cell = ThemeTableViewCell(withLabelColorUpdates: false)
		self.cell?.textLabel?.text = title
		self.cell?.textLabel?.textAlignment = alignment
		self.cell?.accessoryView = accessoryView
		self.cell?.accessibilityIdentifier = identifier

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		themeApplierToken = Theme.shared.add(applier: { [weak self] (_, themeCollection, _) in
			var textColor, selectedTextColor, backgroundColor, selectedBackgroundColor : UIColor?

			textColor = themeCollection.tintColor
			backgroundColor = themeCollection.tableRowColors.backgroundColor

			self?.cell?.textLabel?.textColor = textColor

			if selectedTextColor != nil {
				self?.cell?.textLabel?.highlightedTextColor = selectedTextColor
			}

			if backgroundColor != nil {

				self?.cell?.backgroundColor = backgroundColor
			}

			if selectedBackgroundColor != nil {
				let selectedBackgroundView = UIView()

				selectedBackgroundView.backgroundColor = selectedBackgroundColor

				self?.cell?.selectedBackgroundView? = selectedBackgroundView
			}
			}, applyImmediately: true)

		if rowWithAction != nil {
			self.action = rowWithAction
		} else {
			self.cell?.selectionStyle = .none
		}
	}

	convenience init(rowWithAction: StaticTableViewRowAction?, title: String, alignment: NSTextAlignment = .left, image: UIImage? = nil, imageTintColorKey : String = "labelColor", accessoryType: UITableViewCell.AccessoryType = UITableViewCell.AccessoryType.none, accessoryView: UIView?, identifier: String? = nil) {
		self.init()
		type = .row

		self.identifier = identifier

		self.cell = ThemeTableViewCell(style: .default, reuseIdentifier: nil)

		guard let cell = self.cell else { return }

		cell.textLabel?.text = title
		cell.textLabel?.textAlignment = alignment
		cell.accessoryType = accessoryType
		self.cell?.imageView?.image = image
		cell.accessibilityIdentifier = identifier
		if rowWithAction != nil {
			self.action = rowWithAction
		} else {
			self.cell?.selectionStyle = .none
		}

		if let accessoryView = accessoryView {
			cell.textLabel?.numberOfLines = 0
			additionalAccessoryView = accessoryView

			cell.contentView.addSubview(accessoryView)
			accessoryView.translatesAutoresizingMaskIntoConstraints = false

			NSLayoutConstraint.activate([
				accessoryView.trailingAnchor.constraint(equalTo: cell.accessoryView?.leadingAnchor ?? cell.contentView.trailingAnchor, constant: -5.0),
				accessoryView.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),
				accessoryView.heightAnchor.constraint(equalToConstant: 24.0),
				accessoryView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
			])
		}

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		themeApplierToken = Theme.shared.add(applier: { [weak self] (_, themeCollection, _) in
			self?.cell?.imageView?.tintColor = themeCollection.tableRowColors.value(forKeyPath: imageTintColorKey) as? UIColor
		})
	}

	convenience init(subtitleRowWithAction: StaticTableViewRowAction?, title: String, subtitle: String? = nil, style : UITableViewCell.CellStyle = .subtitle, accessoryType: UITableViewCell.AccessoryType = UITableViewCell.AccessoryType.none, identifier : String? = nil) {
		self.init()
		type = .subtitleRow

		self.identifier = identifier

		self.cell = ThemeTableViewCell(style: style, reuseIdentifier: nil)
		self.cell?.textLabel?.text = title
		self.cell?.detailTextLabel?.text = subtitle
		self.cell?.accessoryType = accessoryType

		self.cell?.accessibilityIdentifier = identifier

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		self.action = subtitleRowWithAction

		self.updateViewFromValue = { (row) in
			if let value = row.value as? String {
				row.cell?.detailTextLabel?.text = value
			}
		}
	}

	convenience init(valueRowWithAction: StaticTableViewRowAction?, title: String, value: String, accessoryType: UITableViewCell.AccessoryType = UITableViewCell.AccessoryType.none, identifier : String? = nil) {
		self.init(subtitleRowWithAction: valueRowWithAction, title: title, subtitle: value, style: .value1, accessoryType: accessoryType, identifier: identifier)
		type = .valueRow
	}

	// MARK: - Radio Item
	convenience init(radioItemWithAction: StaticTableViewRowAction?, groupIdentifier: String, value: Any, title: String, subtitle: String? = nil, selected: Bool, identifier : String? = nil) {
		self.init()
		type = .radio

		var tableViewStyle = UITableViewCell.CellStyle.default
		self.identifier = identifier
		if subtitle != nil {
			tableViewStyle = UITableViewCell.CellStyle.subtitle
		}

		self.cell = ThemeTableViewCell(style: tableViewStyle, reuseIdentifier: nil)
		self.cell?.textLabel?.text = title
		if subtitle != nil {
			self.cell?.detailTextLabel?.text = subtitle
			self.cell?.detailTextLabel?.numberOfLines = 0
		}

		if let accessibilityIdentifier : String = identifier {
			self.cell?.accessibilityIdentifier = groupIdentifier + "." + accessibilityIdentifier
		}

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		self.groupIdentifier = groupIdentifier
		self.value = value

		if selected {
			self.cell?.accessoryType = UITableViewCell.AccessoryType.checkmark
		}

		self.action = { (row, sender) in
			row.section?.setSelected(row.value!, groupIdentifier: row.groupIdentifier!)
			radioItemWithAction?(row, sender)
		}
	}

	// MARK: - Toggle Item
	convenience init(toggleItemWithAction: StaticTableViewRowAction?, title: String, subtitle: String? = nil, selected: Bool, identifier : String? = nil) {
		self.init()
		type = .toggle

		var tableViewStyle : UITableViewCell.CellStyle = .default
		self.identifier = identifier
		if subtitle != nil {
			tableViewStyle = .subtitle
		}

		self.cell = ThemeTableViewCell(style: tableViewStyle, reuseIdentifier: nil)
		self.cell?.textLabel?.text = title
		if subtitle != nil {
			self.cell?.detailTextLabel?.text = subtitle
			self.cell?.detailTextLabel?.numberOfLines = 0
		}

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		if let accessibilityIdentifier : String = identifier {
			self.cell?.accessibilityIdentifier = accessibilityIdentifier
		}

		if selected {
			self.cell?.accessoryType = .checkmark
			self.value = true
		} else {
			self.value = false
		}

		self.action = { (row, sender) in

			guard let value = row.value as? Bool else { return }
			if value {
				row.cell?.accessoryType = .none
				row.value = false
			} else {
				row.cell?.accessoryType = .checkmark
				row.value = true
			}

			toggleItemWithAction?(row, sender)
		}
	}

	// MARK: - Text Field
	public var textField : UITextField?

	convenience init(textFieldWithAction action: StaticTableViewRowTextAction?, placeholder placeholderString: String = "", value textValue: String = "", secureTextEntry : Bool = false, keyboardType: UIKeyboardType = .default, autocorrectionType: UITextAutocorrectionType = .default, autocapitalizationType: UITextAutocapitalizationType = UITextAutocapitalizationType.none, enablesReturnKeyAutomatically: Bool = true, returnKeyType : UIReturnKeyType = .default, inputAccessoryView : UIView? = nil, identifier : String? = nil, accessibilityLabel: String? = nil, actionEvent: UIControl.Event = .editingChanged) {
		self.init()
		type = .text

		self.identifier = identifier

		self.cell = ThemeTableViewCell(withLabelColorUpdates: true)
		self.cell?.selectionStyle = .none

		self.textFieldAction = action
		self.value = textValue

		let cellTextField : UITextField = UITextField()

		cellTextField.translatesAutoresizingMaskIntoConstraints = false

		cellTextField.delegate = self
		cellTextField.placeholder = placeholderString
		cellTextField.keyboardType = keyboardType
		cellTextField.autocorrectionType = autocorrectionType
		cellTextField.isSecureTextEntry = secureTextEntry
		cellTextField.autocapitalizationType = autocapitalizationType
		cellTextField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
		cellTextField.returnKeyType = returnKeyType
		cellTextField.inputAccessoryView = inputAccessoryView
		cellTextField.text = textValue
		cellTextField.accessibilityIdentifier = identifier

		cellTextField.addTarget(self, action: #selector(textFieldContentChanged(_:)), for: actionEvent)

		if cell != nil {
			cell?.contentView.addSubview(cellTextField)
			cellTextField.leftAnchor.constraint(equalTo: (cell?.contentView.leftAnchor)!, constant:18).isActive = true
			cellTextField.rightAnchor.constraint(equalTo: (cell?.contentView.rightAnchor)!, constant:-18).isActive = true
			cellTextField.topAnchor.constraint(equalTo: (cell?.contentView.topAnchor)!, constant:14).isActive = true
			cellTextField.bottomAnchor.constraint(equalTo: (cell?.contentView.bottomAnchor)!, constant:-14).isActive = true
		}

		self.updateViewFromValue = { [weak cellTextField] (row) in
			cellTextField?.text = row.value as? String
		}

		self.updateViewAppearance = { [weak cellTextField] (row) in
			cellTextField?.isEnabled = row.enabled
			cellTextField?.textColor = row.enabled ? Theme.shared.activeCollection.tableRowColors.labelColor : Theme.shared.activeCollection.tableRowColors.secondaryLabelColor
		}

		self.textField = cellTextField

		themeApplierToken = Theme.shared.add(applier: { [weak self] (_, themeCollection, _) in
			cellTextField.textColor = (self?.enabled == true) ? themeCollection.tableRowColors.labelColor : themeCollection.tableRowColors.secondaryLabelColor
			cellTextField.attributedPlaceholder = NSAttributedString(string: placeholderString, attributes: [.foregroundColor : themeCollection.tableRowColors.secondaryLabelColor])
			cellTextField.keyboardAppearance = themeCollection.keyboardAppearance
		})

		cellTextField.accessibilityLabel = accessibilityLabel
	}

	convenience init(secureTextFieldWithAction action: StaticTableViewRowTextAction?, placeholder placeholderString: String = "", value textValue: String = "", keyboardType: UIKeyboardType = UIKeyboardType.default, autocorrectionType: UITextAutocorrectionType = UITextAutocorrectionType.default, autocapitalizationType: UITextAutocapitalizationType = UITextAutocapitalizationType.none, enablesReturnKeyAutomatically: Bool = true, returnKeyType : UIReturnKeyType = UIReturnKeyType.default, inputAccessoryView : UIView? = nil, identifier : String? = nil, accessibilityLabel: String? = nil, actionEvent: UIControl.Event = UIControl.Event.editingChanged) {
		self.init(	textFieldWithAction: action,
				placeholder: placeholderString,
				value: textValue, secureTextEntry: true,
				keyboardType: keyboardType,
				autocorrectionType: autocorrectionType,
				autocapitalizationType: autocapitalizationType,
				enablesReturnKeyAutomatically: enablesReturnKeyAutomatically,
				returnKeyType: returnKeyType,
				inputAccessoryView: inputAccessoryView,
				identifier : identifier,
				accessibilityLabel: accessibilityLabel,
				actionEvent: actionEvent)
		type = .secureText
	}

	@objc func textFieldContentChanged(_ sender: UITextField) {
		self.value = sender.text

		self.textFieldAction?(self, sender, .changed)
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		self.textFieldAction?(self, textField, .didBegin)
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		self.textFieldAction?(self, textField, .didEnd)
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()

		return true
	}

	// MARK: - Labels
	convenience init(label: String, alignment: NSTextAlignment = .left, accessoryView: UIView? = nil, identifier: String? = nil) {
		self.init()
		type = .label

		self.identifier = identifier

		self.cell = ThemeTableViewCell(style: .default, reuseIdentifier: nil)
		self.cell?.textLabel?.text = label
		self.cell?.textLabel?.numberOfLines = 0
		self.cell?.textLabel?.textAlignment = alignment

		if accessoryView != nil {
			self.cell?.accessoryView = accessoryView
			self.cell?.selectionStyle = .none
		} else {
			self.cell?.isUserInteractionEnabled = false
		}

		self.value = label
		self.selectable = false

		self.updateViewFromValue = { (row) in
			if let value = row.value as? String {
				row.cell?.textLabel?.text = value
			}
		}
	}

	// MARK: - Switches
	convenience init(switchWithAction action: StaticTableViewRowAction?, title: String, value switchValue: Bool = false, identifier: String? = nil) {
		self.init()
		type = .switchButton

		self.identifier = identifier

		let switchView = UISwitch()

		self.cell = ThemeTableViewCell(style: .default, reuseIdentifier: nil)
		self.cell?.selectionStyle = .none
		self.cell?.textLabel?.text = title
		self.cell?.accessoryView = switchView

		switchView.isOn = switchValue
		switchView.accessibilityIdentifier = identifier

		self.value = switchValue

		self.action = action

		switchView.addTarget(self, action: #selector(switchValueChanged(_:)), for: UIControl.Event.valueChanged)

		self.updateViewAppearance = { [weak switchView] (row) in
			switchView?.isEnabled = row.enabled
		}

		self.updateViewFromValue = { [weak switchView] (row) in
			if let value = row.value as? Bool {
				switchView?.setOn(value, animated: true)
			}
		}
	}

	@objc func switchValueChanged(_ sender: UISwitch) {
		self.value = sender.isOn

		self.action?(self, sender)
	}

	// MARK: - Buttons

	convenience init(buttonWithAction action: StaticTableViewRowAction?, title: String, style: StaticTableViewRowButtonStyle = .proceed, image: UIImage? = nil, imageWidth : CGFloat? = nil, imageTintColorKey : String? = nil, alignment: NSTextAlignment = .center, identifier : String? = nil, accessoryView: UIView? = nil, accessoryType: UITableViewCell.AccessoryType = .none) {
		self.init()
		type = .button

		self.identifier = identifier

		var image = image
		if image != nil, imageWidth != nil {
			image = image?.paddedTo(width: imageWidth)
		}

		self.cell = ThemeTableViewCell(withLabelColorUpdates: false)
		self.cell?.textLabel?.text = title
		self.cell?.textLabel?.textAlignment = alignment
		self.cell?.imageView?.image = image
		if accessoryView != nil {
			self.cell?.accessoryView = accessoryView
		}
		if accessoryType != .none {
			self.cell?.accessoryType = accessoryType
		}

		self.cell?.accessibilityIdentifier = identifier

		if #available(iOS 13.4, *), let cell = self.cell {
			PointerEffect.install(on: cell.contentView, effectStyle: .hover)
		}

		themeApplierToken = Theme.shared.add(applier: { [weak self] (_, themeCollection, _) in
			var textColor, selectedTextColor, backgroundColor, selectedBackgroundColor : UIColor?

			switch style {
			case .plain:
				textColor = themeCollection.tintColor
				backgroundColor = themeCollection.tableRowColors.backgroundColor

			case .plainNonOpaque:
				textColor = themeCollection.tableRowColors.tintColor
				backgroundColor = themeCollection.tableRowColors.backgroundColor

			case .proceed:
				textColor = themeCollection.neutralColors.normal.foreground
				backgroundColor = themeCollection.neutralColors.normal.background
				selectedBackgroundColor = themeCollection.neutralColors.highlighted.background

			case .destructive:
				textColor = UIColor.red
				backgroundColor = themeCollection.tableRowColors.backgroundColor

			case let .custom(customTextColor, customSelectedTextColor, customBackgroundColor, customSelectedBackgroundColor):
				textColor = customTextColor
				selectedTextColor = customSelectedTextColor
				backgroundColor = customBackgroundColor
				selectedBackgroundColor = customSelectedBackgroundColor
			}

			self?.cell?.textLabel?.tintColor = textColor
			self?.cell?.textLabel?.textColor = textColor
			self?.cell?.imageView?.tintColor = (imageTintColorKey != nil) ? themeCollection.tableRowColors.value(forKeyPath: imageTintColorKey!) as? UIColor : textColor
			self?.cell?.accessoryView?.tintColor = textColor
			self?.cell?.tintColor = themeCollection.tintColor

			if selectedTextColor != nil {

				self?.cell?.textLabel?.highlightedTextColor = selectedTextColor
			}

			if backgroundColor != nil {

				self?.cell?.backgroundColor = backgroundColor
			}

			if selectedBackgroundColor != nil {
				let selectedBackgroundView = UIView()

				selectedBackgroundView.backgroundColor = selectedBackgroundColor

				self?.cell?.selectedBackgroundView? = selectedBackgroundView
			}
		}, applyImmediately: true)

		self.action = action
	}

	// MARK: - Date Picker

	convenience init(datePickerWithAction action: StaticTableViewRowAction?, date dateValue: Date, maximumDate:Date? = nil, identifier: String? = nil) {
		self.init()
		type = .datePicker

		self.identifier = identifier

		let datePickerView = UIDatePicker()
		datePickerView.date = dateValue
		datePickerView.datePickerMode = .date
		datePickerView.minimumDate = Date()
		datePickerView.maximumDate = maximumDate
		datePickerView.accessibilityIdentifier = identifier
		datePickerView.addTarget(self, action: #selector(datePickerValueChanged(_:)), for: UIControl.Event.valueChanged)
		datePickerView.translatesAutoresizingMaskIntoConstraints = false
		datePickerView.setValue(Theme.shared.activeCollection.tableRowColors.labelColor, forKey: "textColor")

		self.cell = ThemeTableViewCell(style: .default, reuseIdentifier: nil)
		self.cell?.selectionStyle = .none
		self.cell?.addSubview(datePickerView)

		self.value = dateValue
		self.action = action

		if let cell = self.cell {
			NSLayoutConstraint.activate([
				datePickerView.leftAnchor.constraint(equalTo: cell.safeAreaLayoutGuide.leftAnchor),
				datePickerView.rightAnchor.constraint(equalTo: cell.safeAreaLayoutGuide.rightAnchor),
				datePickerView.topAnchor.constraint(equalTo: cell.topAnchor),
				datePickerView.heightAnchor.constraint(equalToConstant: 216.0)
				])
		}
	}

	@objc func datePickerValueChanged(_ sender: UIDatePicker) {
		self.action?(self, sender)
	}

	// MARK: - Slider

	convenience init(sliderWithAction action: StaticTableViewRowAction?, minimumValue: Float, maximumValue: Float, value: Float, identifier: String? = nil) {
		self.init()

		let slider = UISlider()
		slider.translatesAutoresizingMaskIntoConstraints = false
		slider.minimumValue = minimumValue
		slider.maximumValue = maximumValue
		slider.value = value
		slider.accessibilityIdentifier = identifier
		slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
		slider.tintColor = Theme.shared.activeCollection.tintColor

		cell = ThemeTableViewCell(style: .default, reuseIdentifier: nil)
		cell?.selectionStyle = .none
		cell?.addSubview(slider)
		type = .slider

		self.value = value
		self.action = action

		if let cell = self.cell {
			NSLayoutConstraint.activate([
				slider.leftAnchor.constraint(equalTo: cell.safeAreaLayoutGuide.leftAnchor, constant: 20),
				slider.rightAnchor.constraint(equalTo: cell.safeAreaLayoutGuide.rightAnchor, constant: -20),
				slider.topAnchor.constraint(equalTo: cell.topAnchor),
				slider.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
			])
		}
	}

	@objc func sliderValueChanged(_ sender: UISlider) {
		action?(self, sender)
	}

	// MARK: - Custom view
	convenience init(customView: UIView, withAction action: StaticTableViewRowAction? = nil, identifier: String? = nil, inset: UIEdgeInsets? = nil, fixedHeight: CGFloat? = nil) {
		self.init()

		cell = ThemeTableViewCell(style: .default, reuseIdentifier: nil)
		cell?.selectionStyle = .none
		cell?.addSubview(customView)

		self.action = action

		if let cell = self.cell {
			var constraints : [NSLayoutConstraint] = []

			customView.translatesAutoresizingMaskIntoConstraints = false

			// Insets
			constraints = [
				customView.leftAnchor.constraint(equalTo: cell.leftAnchor, constant: inset?.left ?? 0),
				customView.rightAnchor.constraint(equalTo: cell.rightAnchor, constant: -(inset?.right ?? 0)),
				customView.topAnchor.constraint(equalTo: cell.topAnchor, constant: inset?.top ?? 0),
				customView.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -(inset?.bottom ?? 0))
			]

			// Fixed height
			if fixedHeight != nil {
				constraints.append(customView.heightAnchor.constraint(equalToConstant: fixedHeight!))
			}

			NSLayoutConstraint.activate(constraints)
		}
	}

	@objc func actionTriggered(_ sender: UIView) {
		action?(self, sender)
	}

	// MARK: - Deinit

	deinit {
		if themeApplierToken != nil {
			Theme.shared.remove(applierForToken: themeApplierToken)
		}
	}
}
