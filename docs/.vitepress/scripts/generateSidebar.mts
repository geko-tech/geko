import { promises as fs } from 'node:fs';
import path from 'node:path';

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

if (import.meta.url === `file://${process.argv[1]}`) {
  const scanDir = process.argv[2];
  const baseUrl = process.argv[3];

  if (!scanDir || !baseUrl) {
    console.error("Usage: node scripts/generateSidebar.mts <scanDir> <baseUrl>");
    process.exit(1);
  }

  const items = await generateSidebar({ scanDir, baseUrl });
  console.log(JSON.stringify(items, null, 2));
}
