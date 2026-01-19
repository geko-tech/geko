import { promises as fs } from "node:fs";
import path from "node:path";

type SidebarItem = {
  text: string;
  link?: string;
  items?: SidebarItem[];
  collapsed?: boolean;
};

type Options = {
  scanDir: string;
  baseUrl: string;
};

function assertBaseUrl(baseUrl: string) {
  if (!baseUrl.startsWith("/") || !baseUrl.endsWith("/")) {
    throw new Error(`baseUrl must start and end with "/": got "${baseUrl}"`);
  }
}

function toPosix(p: string) {
  return p.split(path.sep).join("/");
}

function capFirst(s: string) {
  if (!s) return s;
  return s[0].toUpperCase() + s.slice(1);
}

function stripMd(name: string) {
  return name.toLowerCase().endsWith(".md") ? name.slice(0, -3) : name;
}

async function isFile(p: string) {
  try {
    return (await fs.stat(p)).isFile();
  } catch {
    return false;
  }
}

function mdRelToRoute(relMdPath: string, baseUrl: string): string {
  const rel = toPosix(relMdPath);
  const noExt = stripMd(rel);

  if (noExt === "index") return baseUrl;

  if (noExt.endsWith("/index")) {
    const folder = noExt.slice(0, -"/index".length);
    return `${baseUrl}${folder}/`;
  }

  return `${baseUrl}${noExt}`;
}

async function readDirSorted(absDir: string) {
  const entries = await fs.readdir(absDir, { withFileTypes: true });
  entries.sort((a, b) => a.name.localeCompare(b.name));
  return entries;
}

async function buildItems(
  absDir: string,
  relDir: string,
  baseUrl: string
): Promise<SidebarItem[]> {
  const entries = await readDirSorted(absDir);

  const dirs = entries.filter((e) => e.isDirectory());
  const mdFiles = entries.filter(
    (e) => e.isFile() && e.name.toLowerCase().endsWith(".md")
  );

  const mdNonIndex = mdFiles.filter((f) => f.name.toLowerCase() !== "index.md");

  const fileItems: SidebarItem[] = mdNonIndex.map((f) => {
    const relFile = relDir ? `${relDir}/${f.name}` : f.name;
    const text = stripMd(f.name);
    return {
      text,
      link: mdRelToRoute(relFile, baseUrl),
    };
  });

  const dirItems: SidebarItem[] = [];
  for (const d of dirs) {
    const absSub = path.join(absDir, d.name);
    const relSub = relDir ? `${relDir}/${d.name}` : d.name;

    const indexAbs = path.join(absSub, "index.md");
    const hasIndex = await isFile(indexAbs);

    const children = await buildItems(absSub, relSub, baseUrl);

    if (!hasIndex && children.length === 0) continue;

    const item: SidebarItem = {
      text: capFirst(d.name),
      collapsed: true,
      items: children.length ? children : undefined,
      link: hasIndex ? mdRelToRoute(`${relSub}/index.md`, baseUrl) : undefined,
    };

    dirItems.push(item);
  }

  return [...dirItems, ...fileItems];
}

export async function generateSidebar(opts: Options): Promise<SidebarItem[]> {
  assertBaseUrl(opts.baseUrl);

  const absScanDir = path.resolve(process.cwd(), opts.scanDir);
  const st = await fs.stat(absScanDir).catch(() => null);
  if (!st?.isDirectory()) {
    throw new Error(`scanDir not found or not a directory: ${absScanDir}`);
  }

  return buildItems(absScanDir, "", opts.baseUrl);
}

/**
 * ---------- Ordered + titled sidebar generation ----------
 *
 * Features:
 * - Reads `title` and `order` from frontmatter (--- ... ---) at the top of *.md
 * - Folder title/order are taken from its `index.md` (if present), else fallback to folder name
 * - Sorting:
 *    1) order ASC (if present)
 *    2) then text/name ASC
 * - Folder items are collapsed by default
 *
 * Frontmatter example:
 * ---
 * title: Directory structure
 * order: 20
 * ---
 */
type OrderedOptions = Options & {
  collapsedFolders?: boolean; // default true
  capitalizeFolderNames?: boolean; // default true
  // If true, file titles fall back to first "# Heading" when frontmatter title is missing
  useTitleFromFileHeading?: boolean; // default false
};

type Meta = { title?: string; order?: number };

async function readTextFileSafe(absPath: string): Promise<string | null> {
  try {
    return await fs.readFile(absPath, "utf8");
  } catch {
    return null;
  }
}

function parseFrontmatterMeta(md: string): Meta {
  if (!md.startsWith("---")) return {};

  const end = md.indexOf("\n---", 3);
  if (end === -1) return {};

  const fmBlock = md.slice(3, end).trim();
  const lines = fmBlock.split(/\r?\n/);

  const meta: Meta = {};
  for (const line of lines) {
    const m = line.match(/^\s*([A-Za-z0-9_-]+)\s*:\s*(.+?)\s*$/);
    if (!m) continue;

    const key = m[1];
    let val = m[2];

    val = val.replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");

    if (key === "title") meta.title = val;
    if (key === "order") {
      const n = Number(val);
      if (!Number.isNaN(n)) meta.order = n;
    }
  }
  return meta;
}

function parseFirstH1(md: string): string | undefined {
  const m = md.match(/^\s*#\s+(.+?)\s*$/m);
  return m?.[1]?.trim();
}

async function getMdMeta(
  absMdPath: string,
  useH1: boolean
): Promise<Meta & { h1?: string }> {
  const md = await readTextFileSafe(absMdPath);
  if (md == null) return {};

  const meta = parseFrontmatterMeta(md);
  if (useH1 && !meta.title) {
    const h1 = parseFirstH1(md);
    if (h1) return { ...meta, h1 };
  }
  return meta;
}

function compareByOrderThenText(
  a: { order?: number; text: string },
  b: { order?: number; text: string }
) {
  const ao = a.order;
  const bo = b.order;

  const aHas = typeof ao === "number";
  const bHas = typeof bo === "number";

  if (aHas && bHas && ao !== bo) return ao - bo;
  if (aHas && !bHas) return -1;
  if (!aHas && bHas) return 1;

  return a.text.localeCompare(b.text);
}

async function readDirUnsorted(absDir: string) {
  return fs.readdir(absDir, { withFileTypes: true });
}

async function buildItemsOrdered(
  absDir: string,
  relDir: string,
  baseUrl: string,
  opts: Required<
    Pick<
      OrderedOptions,
      "collapsedFolders" | "capitalizeFolderNames" | "useTitleFromFileHeading"
    >
  >
): Promise<SidebarItem[]> {
  const entries = await readDirUnsorted(absDir);

  const dirs = entries.filter((e) => e.isDirectory());
  const mdFiles = entries.filter(
    (e) => e.isFile() && e.name.toLowerCase().endsWith(".md")
  );

  // Files
  const fileRows: Array<{
    item: SidebarItem;
    order?: number;
    text: string;
    isIndex?: boolean;
  }> = [];

  for (const f of mdFiles) {
    const isIndex = f.name.toLowerCase() === "index.md";

    const absFile = path.join(absDir, f.name);
    const relFile = relDir ? `${relDir}/${f.name}` : f.name;

    const meta = await getMdMeta(absFile, opts.useTitleFromFileHeading);

    const fallbackName = isIndex ? "Index" : stripMd(f.name);
    const text = meta.title ?? meta.h1 ?? fallbackName;

    fileRows.push({
      item: { text, link: mdRelToRoute(relFile, baseUrl) },
      order: meta.order,
      text,
      isIndex,
    });
  }

  fileRows.sort((a, b) => {
    return compareByOrderThenText(a, b);
  });

  // Directories
  const dirRows: Array<{ item: SidebarItem; order?: number; text: string }> = [];
  for (const d of dirs) {
    const absSub = path.join(absDir, d.name);
    const relSub = relDir ? `${relDir}/${d.name}` : d.name;

    const indexAbs = path.join(absSub, "index.md");
    const hasIndex = await isFile(indexAbs);

    const children = await buildItemsOrdered(absSub, relSub, baseUrl, opts);
    if (!hasIndex && children.length === 0) continue;

    // Folder meta from index.md if exists
    let folderTitle = d.name;
    let folderOrder: number | undefined;

    if (hasIndex) {
      const meta = await getMdMeta(indexAbs, opts.useTitleFromFileHeading);
      if (meta.title) folderTitle = meta.title;
      else if (meta.h1) folderTitle = meta.h1;
      if (typeof meta.order === "number") folderOrder = meta.order;
    }

    if (opts.capitalizeFolderNames) folderTitle = capFirst(folderTitle);

    const item: SidebarItem = {
      text: folderTitle,
      collapsed: opts.collapsedFolders,
      items: children.length ? children : undefined,
      link: undefined,
    };

    dirRows.push({ item, order: folderOrder, text: folderTitle });
  }

  dirRows.sort(compareByOrderThenText);

  // folders first, then files
  return [...fileRows.map((r) => r.item), ...dirRows.map((r) => r.item)];
}

export async function generateSidebarOrdered(
  opts: OrderedOptions
): Promise<SidebarItem[]> {
  assertBaseUrl(opts.baseUrl);

  const absScanDir = path.resolve(process.cwd(), opts.scanDir);
  const st = await fs.stat(absScanDir).catch(() => null);
  if (!st?.isDirectory()) {
    throw new Error(`scanDir not found or not a directory: ${absScanDir}`);
  }

  return buildItemsOrdered(absScanDir, "", opts.baseUrl, {
    collapsedFolders: opts.collapsedFolders ?? true,
    capitalizeFolderNames: opts.capitalizeFolderNames ?? true,
    useTitleFromFileHeading: opts.useTitleFromFileHeading ?? false,
  });
}

export type SidebarSectionOptions = {
  sectionText: string;
  collapsed?: boolean;
};

export function wrapSidebarSection(
  items: SidebarItem[],
  opts: SidebarSectionOptions
): SidebarItem {
  const some = {
    text: opts.sectionText,
    collapsed: opts.collapsed ?? undefined,
    items: items,
  };
  return some;
}
