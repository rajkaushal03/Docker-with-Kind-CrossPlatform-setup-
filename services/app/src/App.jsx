import { useEffect, useState } from 'react'
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from '@firebase/auth'
import { auth, firebaseConfigured } from './firebase'
import './App.css'

const APP_STARTED_AT = Date.now()
const RECENT_WINDOW_MS = 7 * 24 * 60 * 60 * 1000

function getCurrentTimestamp() {
  return Date.now()
}

const starterBookmarks = [
  {
    id: 'starter-1',
    url: 'https://www.notion.so/blog',
    title: 'The Notion Blog',
    description: 'Ideas and inspiration for your best work.',
    domain: 'notion.so',
    favicon: 'https://www.google.com/s2/favicons?domain=notion.so&sz=64',
    tags: ['Inspiration', 'Work'],
    date: 'Today',
    createdAt: APP_STARTED_AT,
    color: 'lavender',
    summary: '',
  },
  {
    id: 'starter-2',
    url: 'https://www.nngroup.com/articles/',
    title: 'Nielsen Norman Group',
    description: 'Evidence-based user experience research, training, and consulting.',
    domain: 'nngroup.com',
    favicon: 'https://www.google.com/s2/favicons?domain=nngroup.com&sz=64',
    tags: ['Design', 'Research'],
    date: 'Yesterday',
    createdAt: APP_STARTED_AT,
    color: 'mint',
    summary: '',
  },
  {
    id: 'starter-3',
    url: 'https://css-tricks.com/',
    title: 'CSS-Tricks',
    description: 'A web design and development community.',
    domain: 'css-tricks.com',
    favicon: 'https://www.google.com/s2/favicons?domain=css-tricks.com&sz=64',
    tags: ['Development', 'Design'],
    date: 'Oct 10',
    createdAt: APP_STARTED_AT,
    color: 'peach',
    summary: '',
  },
]

const iconPaths = {
  grid: <><rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" /><rect x="3" y="14" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" /></>,
  bookmark: <><path d="M6 4.75A1.75 1.75 0 0 1 7.75 3h8.5A1.75 1.75 0 0 1 18 4.75V21l-6-3.75L6 21V4.75Z" /><path d="M9 7h6" /></>,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
  tag: <><path d="M20.59 13.41 13.4 20.6a2 2 0 0 1-2.83 0L3 13V4h9l8.59 8.59a2 2 0 0 1 0 2.82Z" /><circle cx="7.5" cy="8.5" r="1" /></>,
  search: <><circle cx="10.8" cy="10.8" r="6.8" /><path d="m16 16 4.2 4.2" /></>,
  plus: <><path d="M12 5v14M5 12h14" /></>,
  sun: <><circle cx="12" cy="12" r="4" /><path d="M12 2v2m0 16v2M4.93 4.93l1.42 1.42m11.3 11.3 1.42 1.42M2 12h2m16 0h2M4.93 19.07l1.42-1.42m11.3-11.3 1.42-1.42" /></>,
  moon: <path d="M20.8 13.1A8.5 8.5 0 0 1 10.9 3.2 8.5 8.5 0 1 0 20.8 13.1Z" />,
  list: <><path d="M9 6h11M9 12h11M9 18h11" /><path d="M4 6h.01M4 12h.01M4 18h.01" /></>,
  external: <><path d="M14 4h6v6M20 4l-9 9" /><path d="M18 13v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h5" /></>,
  more: <><circle cx="5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /></>,
  close: <><path d="m18 6-12 12M6 6l12 12" /></>,
  spark: <><path d="m12 3 1.9 5.8L20 11l-6.1 2.2L12 19l-2-5.8L4 11l6-2.2L12 3Z" /><path d="m19 14 1.1 2.9L23 18l-2.9 1.1L19 22l-1.1-2.9L15 18l2.9-1.1L19 14Z" /></>,
  arrow: <><path d="M5 12h14m-6-6 6 6-6 6" /></>,
  logout: <><path d="M10 17l5-5-5-5m5 5H3" /><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6" /></>,
  check: <path d="m5 12 4 4L19 6" />,
  globe: <><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3a14 14 0 0 1 0 18m0-18a14 14 0 0 0 0 18" /></>,
  lock: <><rect x="4" y="10" width="16" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></>,
}

function Icon({ name, size = 18, className = '' }) {
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {iconPaths[name]}
    </svg>
  )
}

function getStorageKey(user) {
  return user ? `linkwise-bookmarks-${user.uid}` : 'linkwise-bookmarks-guest'
}

function readBookmarks(key) {
  try {
    const saved = localStorage.getItem(key)
    return saved ? JSON.parse(saved) : starterBookmarks
  } catch (error) {
    console.error('Could not load saved bookmarks:', error)
    return starterBookmarks
  }
}

function App() {
  const [user, setUser] = useState(null)
  const [bookmarkCollections, setBookmarkCollections] = useState(() => ({
    [getStorageKey(null)]: readBookmarks(getStorageKey(null)),
  }))
  const [darkMode, setDarkMode] = useState(() => localStorage.getItem('linkwise-theme') === 'dark')
  const [search, setSearch] = useState('')
  const [selectedTag, setSelectedTag] = useState('All bookmarks')
  const [viewMode, setViewMode] = useState('grid')
  const [urlInput, setUrlInput] = useState('')
  const [tagInput, setTagInput] = useState('')
  const [adding, setAdding] = useState(false)
  const [addError, setAddError] = useState('')
  const [authOpen, setAuthOpen] = useState(false)
  const [authMode, setAuthMode] = useState('login')
  const [authEmail, setAuthEmail] = useState('')
  const [authPassword, setAuthPassword] = useState('')
  const [authError, setAuthError] = useState('')
  const [authBusy, setAuthBusy] = useState(false)
  const [summaryBusy, setSummaryBusy] = useState('')
  const [notice, setNotice] = useState('')

  const storageKey = getStorageKey(user)
  const bookmarks = bookmarkCollections[storageKey] ?? readBookmarks(storageKey)

  function updateBookmarks(updater) {
    setBookmarkCollections((current) => {
      const currentBookmarks = current[storageKey] ?? readBookmarks(storageKey)
      const nextBookmarks = typeof updater === 'function' ? updater(currentBookmarks) : updater
      return { ...current, [storageKey]: nextBookmarks }
    })
  }

  useEffect(() => {
    if (!firebaseConfigured) return undefined
    return onAuthStateChanged(auth, (signedInUser) => setUser(signedInUser))
  }, [])

  useEffect(() => {
    try {
      localStorage.setItem(storageKey, JSON.stringify(bookmarks))
    } catch (error) {
      console.error('Could not save bookmarks:', error)
    }
  }, [bookmarks, storageKey])

  useEffect(() => {
    document.documentElement.dataset.theme = darkMode ? 'dark' : 'light'
    localStorage.setItem('linkwise-theme', darkMode ? 'dark' : 'light')
  }, [darkMode])

  useEffect(() => {
    function handleShortcut(event) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        document.querySelector('#bookmark-url')?.focus()
      }
      if (event.key === '/' && !['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) {
        event.preventDefault()
        document.querySelector('.search-box input')?.focus()
      }
    }
    window.addEventListener('keydown', handleShortcut)
    return () => window.removeEventListener('keydown', handleShortcut)
  }, [])

  useEffect(() => {
    if (!notice) return undefined
    const timeout = window.setTimeout(() => setNotice(''), 3200)
    return () => window.clearTimeout(timeout)
  }, [notice])

  const tags = [...new Set(bookmarks.flatMap((bookmark) => bookmark.tags))].sort()
  const filteredBookmarks = bookmarks.filter((bookmark) => {
    const matchesTag = selectedTag === 'All bookmarks' || (selectedTag === 'Recently added' ? APP_STARTED_AT - (bookmark.createdAt || 0) < RECENT_WINDOW_MS : bookmark.tags.includes(selectedTag))
    const query = search.trim().toLowerCase()
    const matchesSearch = !query || `${bookmark.title} ${bookmark.description} ${bookmark.domain} ${bookmark.tags.join(' ')}`.toLowerCase().includes(query)
    return matchesTag && matchesSearch
  })
  const recentCount = bookmarks.filter((bookmark) => APP_STARTED_AT - (bookmark.createdAt || 0) < RECENT_WINDOW_MS).length

  async function handleAddBookmark(event) {
    event.preventDefault()
    const input = urlInput.trim()
    let parsedUrl
    try {
      parsedUrl = new URL(/^[a-zA-Z][a-zA-Z\d+.-]*:\/\//.test(input) ? input : `https://${input}`)
      if (!['http:', 'https:'].includes(parsedUrl.protocol)) throw new Error('Enter a valid web address.')
    } catch {
      setAddError('Enter a valid web address, like https://example.com')
      return
    }

    if (bookmarks.some((bookmark) => bookmark.url === parsedUrl.href)) {
      setAddError('You have already saved this link.')
      return
    }

    setAdding(true)
    setAddError('')
    setUrlInput('')
    const domain = parsedUrl.hostname.replace(/^www\./, '')
    const newBookmark = {
      id: crypto.randomUUID(),
      url: parsedUrl.href,
      title: domain,
      description: 'Fetching page details…',
      domain,
      favicon: `https://www.google.com/s2/favicons?domain=${encodeURIComponent(domain)}&sz=64`,
      tags: tagInput.split(',').map((tag) => tag.trim()).filter(Boolean),
      date: 'Just now',
      createdAt: getCurrentTimestamp(),
      color: ['lavender', 'mint', 'peach', 'blue'][bookmarks.length % 4],
      summary: '',
    }
    updateBookmarks((current) => [newBookmark, ...current])
    setTagInput('')

    try {
      const response = await fetch(`https://r.jina.ai/${parsedUrl.href}`, { signal: AbortSignal.timeout(18000) })
      if (!response.ok) throw new Error(`Page details request failed (${response.status}).`)
      const content = await response.text()
      const titleMatch = content.match(/^(?:Title:\s*)?(.{3,100})$/m)
      const descriptionMatch = content.match(/^(?:Description:\s*)(.+)$/m)
      updateBookmarks((current) => current.map((bookmark) => bookmark.id === newBookmark.id ? {
        ...bookmark,
        title: titleMatch?.[1]?.replace(/^#+\s*/, '').trim() || bookmark.title,
        description: descriptionMatch?.[1]?.trim() || 'Saved to your reading list.',
      } : bookmark))
    } catch (error) {
      console.warn('Page metadata could not be fetched:', error)
      updateBookmarks((current) => current.map((bookmark) => bookmark.id === newBookmark.id ? { ...bookmark, description: 'Saved to your reading list.' } : bookmark))
      setNotice('Link saved. Page details could not be fetched.')
    } finally {
      setAdding(false)
    }
  }

  async function handleSummarize(bookmark) {
    const endpoint = import.meta.env.VITE_SUMMARIZE_API_URL
    if (!endpoint) {
      setNotice('Add VITE_SUMMARIZE_API_URL to enable AI summaries.')
      return
    }
    setSummaryBusy(bookmark.id)
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: bookmark.url, title: bookmark.title }),
      })
      if (!response.ok) throw new Error(`Summary request failed (${response.status}).`)
      const result = await response.json()
      if (typeof result.summary !== 'string' || !result.summary.trim()) throw new Error('The summary service returned no summary.')
      updateBookmarks((current) => current.map((item) => item.id === bookmark.id ? { ...item, summary: result.summary.trim() } : item))
    } catch (error) {
      console.error('Could not summarize bookmark:', error)
      setNotice(error.message || 'Could not summarize this link.')
    } finally {
      setSummaryBusy('')
    }
  }

  async function handleAuth(event) {
    event.preventDefault()
    setAuthError('')
    if (!firebaseConfigured) {
      setAuthError('Firebase is not configured yet. Add your Firebase settings to .env.local.')
      return
    }
    setAuthBusy(true)
    try {
      if (authMode === 'signup') {
        await createUserWithEmailAndPassword(auth, authEmail, authPassword)
      } else {
        await signInWithEmailAndPassword(auth, authEmail, authPassword)
      }
      setAuthOpen(false)
      setAuthEmail('')
      setAuthPassword('')
    } catch (error) {
      setAuthError(error.message || 'Authentication failed. Please try again.')
    } finally {
      setAuthBusy(false)
    }
  }

  async function handleSignOut() {
    try {
      await signOut(auth)
    } catch (error) {
      console.error('Could not sign out:', error)
      setNotice('Could not sign out. Please try again.')
    }
  }

  function deleteBookmark(id) {
    updateBookmarks((current) => current.filter((bookmark) => bookmark.id !== id))
    setNotice('Bookmark deleted.')
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <a className="brand" href="/" aria-label="Linkwise home">
          <span className="brand-mark"><Icon name="bookmark" size={21} /></span>
          <span>linkwise<span className="brand-period">.</span></span>
        </a>
        <button className="sidebar-add" onClick={() => document.querySelector('#bookmark-url')?.focus()}>
          <Icon name="plus" size={18} /><span>Save a link</span><kbd>⌘ K</kbd>
        </button>
        <div className="side-label">LIBRARY</div>
        <nav className="side-nav" aria-label="Bookmark filters">
          <button className={`nav-item ${selectedTag === 'All bookmarks' ? 'active' : ''}`} onClick={() => setSelectedTag('All bookmarks')}>
            <Icon name="grid" /><span>All bookmarks</span><span className="nav-count">{bookmarks.length}</span>
          </button>
          <button className={`nav-item ${selectedTag === 'Recently added' ? 'active' : ''}`} onClick={() => setSelectedTag('Recently added')}>
            <Icon name="clock" /><span>Recently added</span>{recentCount > 0 && <span className="nav-count">{recentCount}</span>}
          </button>
        </nav>
        <div className="side-label tags-heading"><span>YOUR TAGS</span><Icon name="more" size={17} /></div>
        <nav className="side-nav tag-nav" aria-label="Filter by tag">
          {tags.length ? tags.map((tag, index) => (
            <button key={tag} className={`nav-item ${selectedTag === tag ? 'active' : ''}`} onClick={() => setSelectedTag(tag)}>
              <span className={`tag-dot dot-${index % 5}`} /><span>{tag}</span><span className="nav-count">{bookmarks.filter((bookmark) => bookmark.tags.includes(tag)).length}</span>
            </button>
          )) : <p className="no-tags">Add tags to organize your links.</p>}
        </nav>
        <div className="sidebar-bottom">
          <div className="storage-card">
            <div className="storage-icon"><Icon name={user ? 'check' : 'lock'} size={16} /></div>
            <div><strong>{user ? 'Signed-in account' : 'Private by default'}</strong><p>{user ? user.email : 'Your links stay in this browser'}</p></div>
          </div>
          <button className="user-row" onClick={() => user ? handleSignOut() : (setAuthOpen(true), setAuthMode('login'))}>
            <span className="avatar">{user ? user.email?.[0]?.toUpperCase() : 'G'}</span>
            <span className="user-details"><strong>{user ? user.email?.split('@')[0] : 'Guest mode'}</strong><small>{user ? 'Sign out' : 'Sign in to your account'}</small></span>
            <Icon name={user ? 'logout' : 'arrow'} size={17} />
          </button>
        </div>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <div className="breadcrumb"><span>Library</span><span className="crumb-slash">/</span><strong>{selectedTag}</strong></div>
          <div className="top-actions">
            <div className="search-box">
              <Icon name="search" size={17} />
              <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search your links..." aria-label="Search bookmarks" />
              <kbd>/</kbd>
            </div>
            <button className="icon-button theme-toggle" onClick={() => setDarkMode((current) => !current)} aria-label={`Switch to ${darkMode ? 'light' : 'dark'} mode`}>
              <Icon name={darkMode ? 'sun' : 'moon'} size={18} />
            </button>
            {!user && <button className="signin-button" onClick={() => { setAuthMode('login'); setAuthOpen(true) }}>Sign in</button>}
          </div>
        </header>

        <div className="content-wrap">
          <section className="welcome-row">
            <div>
              <div className="eyebrow"><span className="eyebrow-dot" /> YOUR PERSONAL CORNER OF THE INTERNET</div>
              <h1>{selectedTag === 'All bookmarks' ? 'Your library' : selectedTag}<span className="heading-period">.</span></h1>
              <p className="welcome-copy">A thoughtful place for all the things you want to come back to.</p>
            </div>
            <div className="welcome-illustration" aria-hidden="true">
              <div className="illustration-sun" /><div className="illustration-book"><span /><span /><span /></div>
              <div className="illustration-leaf leaf-one" /><div className="illustration-leaf leaf-two" />
            </div>
          </section>

          <form className="add-link-form" onSubmit={handleAddBookmark}>
            <div className="input-icon"><Icon name="globe" size={19} /></div>
            <input id="bookmark-url" value={urlInput} onChange={(event) => { setUrlInput(event.target.value); setAddError('') }} placeholder="Paste a link to save it for later..." aria-label="URL to bookmark" />
            <input className="tag-entry" value={tagInput} onChange={(event) => setTagInput(event.target.value)} placeholder="Add tags (comma separated)" aria-label="Tags, comma separated" />
            <button className="save-button" type="submit" disabled={adding || !urlInput.trim()}><Icon name="plus" size={17} /><span>{adding ? 'Saving…' : 'Save link'}</span></button>
          </form>
          {addError && <p className="form-error">{addError}</p>}
          <div className="form-hint"><Icon name="spark" size={14} /> We'll fetch the page title and favicon for you</div>

          <section className="summary-showcase" aria-labelledby="showcase-title">
            <div className="showcase-intro">
              <span className="showcase-kicker"><Icon name="spark" size={14} /> A LITTLE CLARITY, AUTOMATICALLY</span>
              <h2 id="showcase-title">From open tabs to <span>“aha.”</span></h2>
              <p>Turn a long read into the ideas worth remembering.</p>
              <button className="showcase-cta" onClick={() => document.querySelector('#bookmark-url')?.focus()}>
                Try it with a link <Icon name="arrow" size={16} />
              </button>
            </div>
            <div className="code-window" aria-label="Example of an AI-generated link summary">
              <div className="code-toolbar">
                <div className="window-dots" aria-hidden="true"><span /><span /><span /></div>
                <span className="code-tab"><Icon name="spark" size={13} /> linkwise / summary-preview</span>
                <span className="example-badge">EXAMPLE</span>
              </div>
              <div className="code-content" aria-hidden="true">
                <div className="code-line"><span className="code-prompt">›</span><span><span className="code-purple">const</span> link = <span className="code-yellow">"your-next-great-read.com"</span>;</span></div>
                <div className="code-line"><span className="code-prompt">›</span><span><span className="code-purple">await</span> linkwise.read(link);</span></div>
                <div className="code-line code-comment"><span className="code-prompt">›</span><span>// finding the useful bits...</span></div>
                <div className="code-line code-comment"><span className="code-prompt">›</span><span>// connecting ideas, skipping the noise...</span></div>
                <div className="code-line"><span className="code-prompt">›</span><span><span className="code-purple">const</span> takeaways = <span className="code-purple">await</span> linkwise.summarize();</span></div>
                <div className="code-line"><span className="code-prompt">›</span><span className="code-muted">{'{'}</span></div>
                <div className="code-line code-result"><span className="code-prompt">›</span><span><span className="code-key">summary</span>: <span className="code-green">"The key ideas, minus the noise."</span><span className="typing-cursor" /></span></div>
              </div>
            </div>
          </section>

          <section className="library-section">
            <div className="section-heading">
              <div><h2>{selectedTag === 'All bookmarks' ? 'All bookmarks' : selectedTag}</h2><span className="result-count">{filteredBookmarks.length} {filteredBookmarks.length === 1 ? 'link' : 'links'}</span></div>
              <div className="view-controls" aria-label="Bookmark view">
                <button className={viewMode === 'grid' ? 'selected' : ''} onClick={() => setViewMode('grid')} aria-label="Grid view"><Icon name="grid" size={17} /></button>
                <button className={viewMode === 'list' ? 'selected' : ''} onClick={() => setViewMode('list')} aria-label="List view"><Icon name="list" size={18} /></button>
              </div>
            </div>
            {filteredBookmarks.length ? (
              <div className={`bookmark-grid ${viewMode}`}>
                {filteredBookmarks.map((bookmark) => (
                  <article className={`bookmark-card ${bookmark.color}`} key={bookmark.id}>
                    <div className="card-topline">
                      <span className="site-favicon"><img src={bookmark.favicon} alt="" onError={(event) => { event.currentTarget.style.visibility = 'hidden' }} /><Icon name="globe" size={17} /></span>
                      <span className="saved-date">{bookmark.date}</span>
                      <button className="card-menu" onClick={() => deleteBookmark(bookmark.id)} title="Delete bookmark" aria-label={`Delete ${bookmark.title}`}><Icon name="close" size={16} /></button>
                    </div>
                    <a className="card-title" href={bookmark.url} target="_blank" rel="noreferrer">{bookmark.title}<Icon name="external" size={14} /></a>
                    <p className="card-description">{bookmark.summary || bookmark.description}</p>
                    {bookmark.tags.length > 0 && <div className="card-tags">{bookmark.tags.map((tag) => <button key={tag} onClick={() => setSelectedTag(tag)}>{tag}</button>)}</div>}
                    <div className="card-footer">
                      <span className="domain-name">{bookmark.domain}</span>
                      <button className="summary-button" disabled={summaryBusy === bookmark.id} onClick={() => handleSummarize(bookmark)}>
                        <Icon name="spark" size={14} />{summaryBusy === bookmark.id ? 'Summarizing…' : bookmark.summary ? 'Summarized' : 'AI summary'}
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              <div className="empty-state">
                <span className="empty-icon"><Icon name={search || selectedTag !== 'All bookmarks' ? 'search' : 'bookmark'} size={23} /></span>
                <h3>{search ? 'No links found' : 'Nothing saved here yet'}</h3>
                <p>{search ? 'Try another search or clear your filters.' : 'Paste a URL above and your next favorite thing is just a click away.'}</p>
                {(search || selectedTag !== 'All bookmarks') && <button onClick={() => { setSearch(''); setSelectedTag('All bookmarks') }}>Clear filters <Icon name="arrow" size={15} /></button>}
              </div>
            )}
          </section>
          <footer className="page-footer"><span>Made for your curious mind <span className="footer-heart">✳</span></span><span>{bookmarks.length} links saved</span></footer>
        </div>
      </main>

      {authOpen && (
        <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setAuthOpen(false) }}>
          <section className="auth-modal" role="dialog" aria-modal="true" aria-labelledby="auth-title">
            <button className="modal-close" onClick={() => setAuthOpen(false)} aria-label="Close"><Icon name="close" /></button>
            <span className="modal-mark"><Icon name="bookmark" size={21} /></span>
            <div className="eyebrow modal-eyebrow">YOUR LINKS, WHEREVER YOU GO</div>
            <h2 id="auth-title">{authMode === 'login' ? 'Welcome back' : 'Create your account'}</h2>
            <p className="modal-copy">{authMode === 'login' ? 'Sign in to pick up right where you left off.' : 'Make a home for all your favorite things on the internet.'}</p>
            <form className="auth-form" onSubmit={handleAuth}>
              <label htmlFor="auth-email">Email address</label>
              <input id="auth-email" type="email" autoComplete="email" value={authEmail} onChange={(event) => setAuthEmail(event.target.value)} placeholder="you@example.com" required />
              <label htmlFor="auth-password">Password</label>
              <input id="auth-password" type="password" autoComplete={authMode === 'login' ? 'current-password' : 'new-password'} minLength="6" value={authPassword} onChange={(event) => setAuthPassword(event.target.value)} placeholder="At least 6 characters" required />
              {authError && <p className="auth-error">{authError}</p>}
              <button className="auth-submit" type="submit" disabled={authBusy}>{authBusy ? 'Please wait…' : authMode === 'login' ? 'Sign in' : 'Create account'}<Icon name="arrow" size={17} /></button>
            </form>
            <p className="auth-switch">{authMode === 'login' ? 'New to Linkwise?' : 'Already have an account?'} <button onClick={() => { setAuthMode(authMode === 'login' ? 'signup' : 'login'); setAuthError('') }}>{authMode === 'login' ? 'Create an account' : 'Sign in'}</button></p>
            <div className="secure-note"><Icon name="lock" size={14} /> Secure authentication powered by Firebase</div>
          </section>
        </div>
      )}
      {notice && <div className="toast" role="status"><Icon name="check" size={17} />{notice}</div>}
    </div>
  )
}

export default App
