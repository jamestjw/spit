// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
// import {Socket} from "phoenix"
// import {LiveSocket} from "phoenix_live_view"
// import {hooks as colocatedHooks} from "phoenix-colocated/spit"
// import topbar from "../vendor/topbar"

// const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// const liveSocket = new LiveSocket("/live", Socket, {
//   longPollFallbackMs: 2500,
//   params: {_csrf_token: csrfToken},
//   hooks: {...colocatedHooks},
// })

// Show progress bar on live navigation and form submits
// topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
// window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
// window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
// liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
// window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
// if (process.env.NODE_ENV === "development") {
//   window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
//     // Enable server log streaming to client.
//     // Disable with reloader.disableServerLogs()
//     reloader.enableServerLogs()
// 
//     // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
//     //
//     //   * click with "c" key pressed to open at caller location
//     //   * click with "d" key pressed to open at function component definition location
//     let keyDown
//     window.addEventListener("keydown", e => keyDown = e.key)
//     window.addEventListener("keyup", _e => keyDown = null)
//     window.addEventListener("click", e => {
//       if(keyDown === "c"){
//         e.preventDefault()
//         e.stopImmediatePropagation()
//         reloader.openEditorAtCaller(e.target)
//       } else if(keyDown === "d"){
//         e.preventDefault()
//         e.stopImmediatePropagation()
//         reloader.openEditorAtDef(e.target)
//       }
//     }, true)
// 
//     window.liveReloader = reloader
//   })
// }


// Handle flash close
document.querySelectorAll("[role=alert][data-flash]").forEach((el) => {
  el.addEventListener("click", () => {
    el.setAttribute("hidden", "")
  })
})

document.querySelectorAll("[data-local-datetime]").forEach((el) => {
  const datetime = new Date(el.dataset.localDatetime)

  if (Number.isNaN(datetime.getTime())) return

  el.textContent = new Intl.DateTimeFormat(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  }).format(datetime)
})

// Paste viewer actions
document.querySelectorAll("[data-copy-target]").forEach((button) => {
  button.addEventListener("click", async () => {
    const target = document.getElementById(button.dataset.copyTarget)

    if (!target) return

    const originalText = button.textContent

    try {
      await navigator.clipboard.writeText(target.textContent)
      button.textContent = "Copied"
      window.setTimeout(() => { button.textContent = originalText }, 1400)
    } catch (_error) {
      button.textContent = "Copy failed"
      window.setTimeout(() => { button.textContent = originalText }, 1400)
    }
  })
})

const pasteViewer = document.getElementById("paste-viewer")

if (pasteViewer?.dataset.encrypted === "true") {
  const encryptedBody = pasteViewer.dataset.encryptedBody
  const keyMatch = window.location.hash.match(/^#key=([0-9a-f]+):([0-9a-f]+)$/)

  if (keyMatch) {
    document.getElementById("decrypt-no-key")?.classList.add("hidden")

    const loading = document.getElementById("decrypt-loading")
    loading?.classList.remove("hidden")
    loading?.classList.add("flex")

    const hexToBytes = (hex) => {
      const bytes = new Uint8Array(hex.length / 2)

      for (let i = 0; i < bytes.length; i++) {
        bytes[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16)
      }

      return bytes
    }

    const showDecryptError = () => {
      document.getElementById("decrypt-error")?.classList.remove("hidden")
      document.getElementById("decrypt-error")?.classList.add("flex")
      loading?.classList.add("hidden")
      loading?.classList.remove("flex")
    }

    const decryptPaste = async () => {
      try {
        if (!encryptedBody || keyMatch[1].length % 2 !== 0 || keyMatch[2].length % 2 !== 0) {
          showDecryptError()
          return
        }

        const keyBytes = hexToBytes(keyMatch[1])
        const ivBytes = hexToBytes(keyMatch[2])
        const encryptedBytes = Uint8Array.from(atob(encryptedBody), (char) => char.charCodeAt(0))
        const key = await crypto.subtle.importKey("raw", keyBytes, "AES-CBC", false, ["decrypt"])
        const decrypted = await crypto.subtle.decrypt({ name: "AES-CBC", iv: ivBytes }, key, encryptedBytes)
        const decryptedText = new TextDecoder().decode(decrypted)

        document.getElementById("decrypted-body").textContent = decryptedText
        document.getElementById("decrypted-content")?.classList.remove("hidden")
        loading?.classList.add("hidden")
        loading?.classList.remove("flex")

        const blob = new Blob([decryptedText], { type: "text/plain" })
        const url = URL.createObjectURL(blob)
        const downloadLink = document.getElementById("download-paste-link")
        const rawLink = document.getElementById("raw-paste-link")
        const copyButton = document.getElementById("copy-paste-button")

        if (downloadLink) {
          downloadLink.classList.remove("opacity-50", "cursor-not-allowed", "pointer-events-none")
          downloadLink.href = url
          downloadLink.setAttribute("download", `paste-${pasteViewer.dataset.pasteSlug}.txt`)
        }

        if (rawLink) {
          rawLink.classList.remove("opacity-50", "cursor-not-allowed", "pointer-events-none")
          rawLink.href = url
          rawLink.target = "_blank"
        }

        copyButton?.classList.remove("opacity-50", "cursor-not-allowed")
        copyButton?.removeAttribute("disabled")
      } catch (_error) {
        showDecryptError()
      }
    }

    decryptPaste()
  }
}
