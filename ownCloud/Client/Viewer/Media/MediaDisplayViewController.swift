//
//  MediaDisplayViewController.swift
//  ownCloud
//
//  Created by Michael Neuwert on 30.06.2019.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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
import AVKit
import MediaPlayer
import ownCloudSDK
import ownCloudAppShared
import CoreServices
import UniformTypeIdentifiers

extension AVPlayer {
    var isAudioAvailable: Bool? {
        return self.currentItem?.asset.tracks.filter({$0.mediaType == .audio}).count != 0
    }

    var isVideoAvailable: Bool? {
        return self.currentItem?.asset.tracks.filter({$0.mediaType == .video}).count != 0
    }
}

class MediaDisplayViewController : DisplayViewController {

	static let MediaPlaybackFinishedNotification = NSNotification.Name("media_playback.finished")
	static let MediaPlaybackNextTrackNotification = NSNotification.Name("media_playback.play_next")
	static let MediaPlaybackPreviousTrackNotification = NSNotification.Name("media_playback.play_previous")

	private var playerStatusObservation: NSKeyValueObservation?
	private var playerItemStatusObservation: NSKeyValueObservation?
	private var playerItem: AVPlayerItem?
	private var player: AVPlayer?
	private var playerViewController: AVPlayerViewController?

	// Information for now playing
	private var mediaItemArtwork: MPMediaItemArtwork?
	private var mediaItemTitle: String?
	private var mediaItemArtist: String?

	private var hasFocus: Bool = false

	public var isPlaying: Bool {
		if player?.rate == 1.0 {
			return true
		}
		return false
	}

	deinit {
		playerStatusObservation?.invalidate()
		playerItemStatusObservation?.invalidate()

		MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

		NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
	}

	var showLoadingIndicator: Bool = false {
		didSet {
			if oldValue != showLoadingIndicator {
				if showLoadingIndicator {
					// Show loading indicator
					let indeterminateProgress: Progress = .indeterminate()
					indeterminateProgress.isCancellable = false

					let messageView = ComposedMessageView.infoBox(additionalElements: [
						.spacing(25),
						.progressCircle(with: indeterminateProgress),
						.spacing(25),
						.title(OCLocalizedString("Loading…", nil), alignment: .centered)
					], withRoundedBackgroundView: true)

					loadingIndicator = messageView
				} else {
					// Remove loading indicator
					loadingIndicator = nil
				}
			}
		}
	}

	private var loadingIndicator: ComposedMessageView? {
		willSet {
			loadingIndicator?.removeFromSuperview()
		}
		didSet {
			if let loadingIndicator {
				view.embed(centered: loadingIndicator)
			}
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(handleDidEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAVPlayerItem(notification:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		hasFocus = true
		player?.play()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		hasFocus = false
		player?.pause()
	}

	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()

		if let playerController = self.playerViewController {
			playerController.view.translatesAutoresizingMaskIntoConstraints = false

			NSLayoutConstraint.activate([
				playerController.view.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
				playerController.view.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
				playerController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
				playerController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
			])
		}

		self.view.layoutIfNeeded()
	}

	override var requiresLocalCopyForPreview : Bool {
		return (OCAppIdentity.shared.userDefaults?.downloadMediaFiles ?? false)
	}

	private var timeControlStatusObservation: NSKeyValueObservation?

	override func renderItem(completion: @escaping (Bool) -> Void) {
		if playerViewController == nil {
			playerViewController = AVPlayerViewController()

			if let playerViewController {
				addChild(playerViewController)
				self.view.addSubview(playerViewController.view)
				playerViewController.didMove(toParent: self)

				playerViewController.view.translatesAutoresizingMaskIntoConstraints = false

				NSLayoutConstraint.activate([
					playerViewController.view.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
					playerViewController.view.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
					playerViewController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
					playerViewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
				])
			}
		}

		if let directURL = itemDirectURL {
			playerItemStatusObservation?.invalidate()
			playerItemStatusObservation = nil
			player?.pause()

			let asset = AVURLAsset(url: directURL, options: self.httpAuthHeaders != nil ? ["AVURLAssetHTTPHeaderFieldsKey" : self.httpAuthHeaders!] : nil )
			playerItem = AVPlayerItem(asset: asset)

			playerItemStatusObservation = playerItem?.observe(\AVPlayerItem.status, options: [.initial, .new], changeHandler: { [weak self] (item, _) in
				if item.status == .failed {
					self?.present(error: item.error)
				}
			})

			if player == nil {
				player = AVPlayer(playerItem: playerItem)
				player?.allowsExternalPlayback = true
				if let playerViewController {
					playerViewController.updatesNowPlayingInfoCenter = false

					if UIApplication.shared.applicationState == .active {
						playerViewController.player = player
					}
				}

				// Start with the loading indicator active
				showLoadingIndicator = true

				// .. it will be updated as soon as the player starts playing ..
				timeControlStatusObservation = player?.observe(\AVPlayer.timeControlStatus, changeHandler: { [weak self] player, change in
					self?.updateLoadingIndicator()
				})

				// Setup player status observation handler
				playerStatusObservation = player!.observe(\AVPlayer.status, options: [.initial, .new], changeHandler: { [weak self] (player, _) in
					if player.status == .readyToPlay {
						self?.updateMediaMetadata()

						self?.setupRemoteTransportControls()

						try? AVAudioSession.sharedInstance().setCategory(.playback)
						try? AVAudioSession.sharedInstance().setActive(true)

						if (self?.hasFocus)! {
							// .. with playback starting here.
							self?.player?.play()
						} else {
							// .. or the loading indicator being updated when the file is ready to play, here.
							self?.updateLoadingIndicator()
						}

						self?.updateNowPlayingInfoCenter()

					} else if player.status == .failed {
						self?.present(error: self?.player?.error)
					}
				})
			} else {
				player!.replaceCurrentItem(with: playerItem)
			}
			completion(true)
		} else {
			completion(false)
		}
	}

	private func updateLoadingIndicator() {
		if let player {
			let showLoadingIndicator = (player.timeControlStatus == .waitingToPlayAtSpecifiedRate)

			OnMainThread(inline: true) {
				self.showLoadingIndicator = showLoadingIndicator
			}
		}
	}

	private func updateMediaMetadata() {
		guard let asset = playerItem?.asset else { return }

		// Add artwork to the player overlay if corresponding meta data item is available in the asset
		if !(player?.isVideoAvailable ?? false), let artworkMetadataItem = asset.commonMetadata.filter({$0.commonKey == AVMetadataKey.commonKeyArtwork}).first,
		   let imageData = artworkMetadataItem.dataValue,
		   let overlayView = playerViewController?.contentOverlayView {

			if let artworkImage = UIImage(data: imageData) {

				// Construct image view overlay for AVPlayerViewController
				OnMainThread(inline: true) { [weak self] in
					let imageView = UIImageView(image: artworkImage)
					imageView.translatesAutoresizingMaskIntoConstraints = false
					imageView.contentMode = .scaleAspectFit
					self?.playerViewController?.contentOverlayView?.addSubview(imageView)

					NSLayoutConstraint.activate([
						imageView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
						imageView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
						imageView.topAnchor.constraint(equalTo: overlayView.topAnchor),
						imageView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor)
					])
				}

				// Create MPMediaItemArtwork to be shown in 'now playing' in the lock screen
				mediaItemArtwork = MPMediaItemArtwork(boundsSize: artworkImage.size, requestHandler: { (_) -> UIImage in
					return artworkImage
				})
			}
		}

		// Extract title meta-data item
		mediaItemTitle = asset.commonMetadata.filter({$0.commonKey == AVMetadataKey.commonKeyTitle}).first?.value as? String

		// Extract artist meta-data item
		mediaItemArtist = asset.commonMetadata.filter({$0.commonKey == AVMetadataKey.commonKeyArtist}).first?.value as? String
	}

	private func present(error:Error?) {
		guard let error = error else { return }

		OnMainThread { [weak self] in
			let alert = ThemedAlertController(with: OCLocalizedString("Error", nil), message: error.localizedDescription, okLabel: OCLocalizedString("OK", nil), action: {
				self?.navigationController?.popViewController(animated: true)
			})

			self?.parent?.present(alert, animated: true)
		}
	}

	private var isInBackground: Bool = false {
		didSet {
			playerViewController?.player = isInBackground ? nil : player
		}
	}

	@objc private func handleDidEnterBackgroundNotification() {
		isInBackground = true
	}

	@objc private func handleWillEnterForegroundNotification() {
		isInBackground = false
	}

	@objc private func handleAVPlayerItem(notification:Notification) {
		try? AVAudioSession.sharedInstance().setActive(false)
		OnMainThread {
			NotificationCenter.default.post(name: MediaDisplayViewController.MediaPlaybackFinishedNotification, object: self.item)
		}
	}

	private func setupRemoteTransportControls() {
		// Get the shared MPRemoteCommandCenter
		let commandCenter = MPRemoteCommandCenter.shared()

		// Add handler for Play Command
		commandCenter.playCommand.addTarget { [weak self] _ in
			if let player = self?.player {
				if player.rate == 0.0 {
					player.play()
					self?.updateNowPlayingTimeline()
					return .success
				}
			}

			return .commandFailed
		}

		// Add handler for Pause Command
		commandCenter.pauseCommand.addTarget { [weak self] _ in
			if let player = self?.player {
				if player.rate == 1.0 {
					player.pause()
					self?.updateNowPlayingTimeline()
					return .success
				}
			}

			return .commandFailed
		}

		// Add handler for skip forward command
		commandCenter.skipForwardCommand.isEnabled = true
		commandCenter.skipForwardCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
			if let player = self?.player {
				let time = player.currentTime() + CMTime(seconds: 10.0, preferredTimescale: 1)
				player.seek(to: time) { (finished) in
					if finished {
						self?.updateNowPlayingTimeline()
					}
				}
				return .success
			}
			return .commandFailed
		}

		// Add handler for skip backward command
		commandCenter.skipBackwardCommand.isEnabled = true
		commandCenter.skipBackwardCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
			if let player = self?.player {
				let time = player.currentTime() - CMTime(seconds: 10.0, preferredTimescale: 1)
				player.seek(to: time) { (finished) in
					if finished {
						self?.updateNowPlayingTimeline()
					}
				}
				return .success
			}
			return .commandFailed
		}

		// TODO: Skip controls are useful for podcasts but not so much for music.
		// Disable them for now but keep the implementation of command handlers
		commandCenter.skipForwardCommand.isEnabled = false
		commandCenter.skipBackwardCommand.isEnabled = false

		// Configure next / previous track buttons according to number of items to be played
		var enableNextTrackCommand = false
		var enablePreviousTrackCommand = false

		if let itemIndex = self.itemIndex {
			if itemIndex > 0 {
				enablePreviousTrackCommand = true
			}

			if let displayHostController = self.parent as? DisplayHostViewController, let items = displayHostController.items {
				enableNextTrackCommand = itemIndex < (items.count - 1)
			}
		}

		commandCenter.nextTrackCommand.isEnabled = enableNextTrackCommand
		commandCenter.previousTrackCommand.isEnabled = enablePreviousTrackCommand

		// Add handler for seek forward command
		commandCenter.nextTrackCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
			if let player = self?.player {
				player.pause()
				OnMainThread {
					NotificationCenter.default.post(name: MediaDisplayViewController.MediaPlaybackNextTrackNotification, object: nil)
				}
				return .success
			}
			return .commandFailed
		}

		// Add handler for seek backward command
		commandCenter.previousTrackCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
			if let player = self?.player {
				player.pause()
				OnMainThread {
					NotificationCenter.default.post(name: MediaDisplayViewController.MediaPlaybackPreviousTrackNotification, object: nil)
				}
				return .success
			}
			return .commandFailed
		}
	}

	private func updateNowPlayingTimeline() {

		MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.playerItem?.currentTime().seconds

		MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = self.player?.rate
	}

	private func updateNowPlayingInfoCenter() {
		guard let player = self.player else { return }
		guard let playerItem = self.playerItem else { return }

		var nowPlayingInfo = [String : Any]()

		nowPlayingInfo[MPMediaItemPropertyTitle] = mediaItemTitle
		nowPlayingInfo[MPMediaItemPropertyArtist] = mediaItemArtist
		nowPlayingInfo[MPNowPlayingInfoPropertyCurrentPlaybackDate] = self.playerItem?.currentDate()
		nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = itemDirectURL
		nowPlayingInfo[MPNowPlayingInfoPropertyCurrentPlaybackDate] = playerItem.currentDate()
		nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
		nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
		nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.asset.duration.seconds

		if mediaItemArtwork != nil {
			nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaItemArtwork
		}

		MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
		updateNowPlayingTimeline()
	}

	public func play() {
		player?.play()
	}

	public func pause() {
		player?.pause()
	}

	public func seek(to: CMTime) {
		player?.seek(to: to)
	}

	public func currentTime() -> CMTime {
		guard let player = player else { return CMTime() }

		return player.currentTime()
	}

	public func toggleMute() {
		if player?.isMuted == false {
			player?.isMuted = true
		} else {
			player?.isMuted = false
		}
	}

	public func enterFullScreen() {
		playerViewController?.enterFullScreen(animated: true)
	}

	public func canEnterFullScreen() -> Bool {
		return playerViewController?.canEnterFullScreen() ?? false
	}
}

extension AVPlayerViewController {
	func enterFullScreen(animated: Bool) {
		let selectorToForceFullScreenMode = NSSelectorFromString("enterFullScreenAnimated:completionHandler:")
		if self.responds(to: selectorToForceFullScreenMode) {
			perform(selectorToForceFullScreenMode, with: animated, with: nil)
		}
	}

	func canEnterFullScreen() -> Bool {
		let selectorToForceFullScreenMode = NSSelectorFromString("enterFullScreenAnimated:completionHandler:")
		if self.responds(to: selectorToForceFullScreenMode) {
			return true
		}

		return false
	}
}

// MARK: - Display Extension.
extension MediaDisplayViewController: DisplayExtension {
	static var customMatcher: OCExtensionCustomContextMatcher? = { (context, defaultPriority) in
		if let mimeType = context.location?.identifier?.rawValue {

			if MediaDisplayViewController.mimeTypeConformsTo(mime: mimeType, utType: UTType.audiovisualContent) {
				return OCExtensionPriority.locationMatch
			}
		}
		return OCExtensionPriority.noMatch
	}
	static var displayExtensionIdentifier: String = "org.owncloud.media"
	static var supportedMimeTypes: [String]?
	static var features: [String : Any]? = [FeatureKeys.canEdit : false]
}
