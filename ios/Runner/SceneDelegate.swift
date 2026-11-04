import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    connectionOptions.urlContexts.forEach { handOff($0.url, path: "cold") }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    URLContexts.forEach { handOff($0.url, path: "warm") }
  }

  // Single entry point for opened URLs; only logs until the import hand-off attaches here.
  private func handOff(_ url: URL, path: String) {
    NSLog("SceneDelegate.handOff %@ %@", path, url.absoluteString)
  }
}
