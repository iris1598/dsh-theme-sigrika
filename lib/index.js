/**
 * DSH warm theme - host half.
 *
 * Serves the theme's artwork. DSH publishes only `/plugins/<pkg>/client.js` and
 * its compiler-generated chunks, so files inside a plugin package are not
 * reachable from the page; a route registered on the webserver is the only
 * supported way to deliver them.
 *
 * The route is same-origin with the page, so the client half references it with
 * a plain absolute path and there is no CSP or CORS concern.
 */
import { createReadStream } from 'node:fs'
import { stat } from 'node:fs/promises'
import { dirname, extname, join, normalize, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const MEDIA_ROOT = normalize(join(HERE, '..', 'media'))

/** Public route prefix. The client half hardcodes the same string. */
const ROUTE = '/theme-warm'

/** Only image types are servable; anything else 404s rather than leaking files. */
const CONTENT_TYPES = {
  '.webp': 'image/webp',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.avif': 'image/avif',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
}

/** The webserver service is required; without it there is no way to serve media. */
export const inject = ['webServer']

function fail(res, status, message) {
  res.statusCode = status
  res.setHeader('Content-Type', 'text/plain; charset=utf-8')
  res.end(message)
}

/**
 * Resolve a request path to a file inside MEDIA_ROOT, or null when the request
 * escapes the root or names a non-image.
 * @param {string} pathname - the raw request pathname.
 * @returns {string | null} absolute file path, or null to answer 404.
 */
function resolveMedia(pathname) {
  let rel
  try {
    rel = decodeURIComponent(pathname.slice(ROUTE.length))
  } catch {
    return null // malformed percent-encoding
  }
  rel = rel.replace(/^\/+/, '')
  if (rel === '') return null

  const target = normalize(join(MEDIA_ROOT, rel))
  // Traversal guard: the resolved path must stay inside the media root.
  if (target !== MEDIA_ROOT && !target.startsWith(MEDIA_ROOT + sep)) return null
  if (!Object.hasOwn(CONTENT_TYPES, extname(target).toLowerCase())) return null

  return target
}

/**
 * Stream one media file, revalidating with an ETag derived from mtime and size
 * so replacing an asset shows up on the next page load instead of sitting in the
 * browser cache.
 */
async function serveMedia(req, res, pathname) {
  const file = resolveMedia(pathname)
  if (file === null) {
    fail(res, 404, 'not found')
    return
  }

  let info
  try {
    info = await stat(file)
  } catch {
    fail(res, 404, 'not found')
    return
  }
  if (!info.isFile()) {
    fail(res, 404, 'not found')
    return
  }

  const etag = `W/"${info.size.toString(16)}-${Math.floor(info.mtimeMs).toString(16)}"`
  res.setHeader('ETag', etag)
  res.setHeader('Cache-Control', 'no-cache')

  if (req.headers['if-none-match'] === etag) {
    res.statusCode = 304
    res.end()
    return
  }

  res.statusCode = 200
  res.setHeader('Content-Type', CONTENT_TYPES[extname(file).toLowerCase()])
  res.setHeader('Content-Length', String(info.size))

  if (req.method === 'HEAD') {
    res.end()
    return
  }

  const stream = createReadStream(file)
  stream.on('error', () => {
    // Headers may already be sent; the only safe recovery is to drop the socket.
    res.destroy()
  })
  stream.pipe(res)
}

/**
 * Mount the media route.
 * @param {import('@deepseek-ai/cordis').Context} ctx - host plugin context.
 */
export function apply(ctx) {
  ctx.effect(
    () =>
      ctx.webServer.register({
        kind: 'prefix',
        path: ROUTE,
        handler: (req, res) => {
          if (req.method !== 'GET' && req.method !== 'HEAD') {
            res.setHeader('Allow', 'GET, HEAD')
            fail(res, 405, 'method not allowed')
            return
          }
          const pathname = (req.url ?? '/').split('?')[0]
          return serveMedia(req, res, pathname)
        },
      }),
    'theme-warm: media route',
  )
}
