[<img src="https://img.shields.io/docker/pulls/difegue/lanraragi.svg">](https://hub.docker.com/r/difegue/lanraragi/)
[<img src="https://img.shields.io/github/downloads/difegue/lanraragi/total.svg">](https://github.com/Difegue/LANraragi/releases)
[<img src="https://img.shields.io/github/release/difegue/lanraragi.svg?label=latest%20release">](https://github.com/Difegue/LANraragi/releases/latest)
[<img src="https://img.shields.io/homebrew/v/lanraragi.svg">](https://formulae.brew.sh/formula/lanraragi)  
[<img src="https://img.shields.io/website/https/lrr.tvc-16.science.svg?label=demo%20website&up_message=online">](https://lrr.tvc-16.science/)
[<img src="https://github.com/Difegue/LANraragi/actions/workflows/push-continuous-integration.yml/badge.svg">](https://github.com/Difegue/LANraragi/actions)
[<img src="https://img.shields.io/discord/612709831744290847">](https://discord.gg/aRQxtbg)

<img src="public/favicon.ico" width="128">  
  
LANraragi
===========

Open source server for archival of comics/manga, running on Mojolicious + Redis.

#### 💬 Talk with other fellow LANraragi Users on [Discord](https://discord.gg/aRQxtbg) or [GitHub Discussions](https://github.com/Difegue/LANraragi/discussions)  

#### [📄 Documentation](https://sugoi.gitbook.io/lanraragi/v/dev) | [⏬ Download](https://github.com/Difegue/LANraragi/releases/latest) | [🎞 Demo](https://lrr.tvc-16.science) | [🪟🌃 Windows Nightlies](https://nightly.link/Difegue/LANraragi/workflows/push-continous-delivery/dev) | [💵 Sponsor Development](https://ko-fi.com/T6T2UP5N)  | [🉐 Buy Stickers!](https://ko-fi.com/s/9e8cf6a479)

<a href="https://hosted.weblate.org/engage/lanraragi/">
<img src="https://hosted.weblate.org/widget/lanraragi/multi-auto.svg" alt="Translation status" />
</a>  

<sub>LANraragi uses Weblate for translation hosting.</sub>  

## Screenshots  

|Main Page, Thumbnail View | Main Page, List View |
|---|---|
| [![archive_thumb](./tools/Documentation/.gitbook/assets/archive_thumb.png)](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/Documentation/.gitbook/assets/archive_thumb.png) | [![archive_list](./tools/Documentation/.gitbook/assets/archive_list.png)](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/Documentation/.gitbook/assets/archive_list.png) |

|Archive Reader | Reader with overlay |
|---|---|
| [![reader](./tools/Documentation/.gitbook/assets/reader.jpg)](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/Documentation/.gitbook/assets/reader.jpg) | [![reader_overlay](./tools/Documentation/.gitbook/assets/reader_overlay.jpg)](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/Documentation/.gitbook/assets/reader_overlay.jpg) |

|Configuration | Plugin Configuration |
|---|---|
| [![cfg](./tools/Documentation/.gitbook/assets/cfg.png)](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/Documentation/.gitbook/assets/cfg.png) | [![cfg_plugin](./tools/Documentation/.gitbook/assets/cfg_plugin.png)](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/Documentation/.gitbook/assets/cfg_plugin.png) |

## Features  

* Stores your comics in archive format. (zip/rar/targz/lzma/7z/xz/cbz/cbr/cbw/pdf supported, barebones support for epub)  

* Read archives directly from your web browser: the server reads from within compressed files using temporary folders.

* Read your archives in dedicated reader software using the built-in OPDS Catalog (now with PSE support!)

* Use the Client API to interact with LANraragi from other programs (Available for [many platforms!](https://sugoi.gitbook.io/lanraragi/v/dev/advanced-usage/external-readers))

* Two different user interfaces : compact archive list with thumbnails-on-hover, or thumbnail view.

* Localized interface with 11 languages.  

* Choose from 5 preinstalled responsive library styles, or add your own with CSS.  

* Add various types of metadata to archives: Full Tag support with Namespaces, Summaries, Chapters, per-page Overlays.

* Store archives in Categories and/or Tankoubons to sort your Library easily

* Import metadata using Plugins automatically when archives are added to LANraragi.

* Download archives from the Internet directly to the server, while using the aforementioned automatic metadata import

* Scan for duplicates within your saved archives

* Backup your database as JSON to carry your tags over to another LANraragi instance.

## Local Homebrew Workflow

This fork includes a local Homebrew workflow for building LANraragi from the
current checkout and managing it as a macOS user service.

After editing local source code, rebuild and restart LANraragi with:

```bash
./tools/build/homebrew/rebuild-local.sh
```

The script will:

* sync `tools/build/homebrew/Lanraragi.rb` into the local tap at
  `/opt/homebrew/Library/Taps/user/homebrew-lanraragi-local/Formula/lanraragi.rb`;
* point the tap formula's `head` to this checkout through `file://.../.git`;
* install with `--HEAD` when LANraragi is not installed yet;
* reinstall without `--HEAD` when the installed package is already a HEAD build;
* switch a stable install to a local HEAD build when needed;
* restart the Homebrew service after a successful build.

Useful service commands:

```bash
brew services info user/lanraragi-local/lanraragi
brew services restart user/lanraragi-local/lanraragi
brew services stop user/lanraragi-local/lanraragi
brew services start user/lanraragi-local/lanraragi
```

Runtime paths can be changed without rebuilding. The Homebrew launcher reads:

```text
~/.config/lanraragi/lanraragi.env
```

If the file does not exist, the launcher creates it from the packaged template at
`/opt/homebrew/etc/lanraragi.env.example`. Edit `~/.config/lanraragi/lanraragi.env`
and uncomment the paths you want to override:

```bash
export LRR_DATA_DIRECTORY="/path/to/content"
export LRR_THUMB_DIRECTORY="/path/to/thumb"
export LRR_DATABASE_DIRECTORY="/path/to/database"
export LRR_LOG_DIRECTORY="/path/to/logs"
export LRR_TEMP_DIRECTORY="/path/to/temp"
```

Apply path changes with:

```bash
brew services restart user/lanraragi-local/lanraragi
```

Useful paths:

```text
Web UI:      http://127.0.0.1:3000
Data:        ~/Library/Application Support/LANraragi
App log:     ~/Library/Logs/LANraragi/lanraragi.log
Service log: /opt/homebrew/var/log/lanraragi.log
Error log:   /opt/homebrew/var/log/lanraragi.err.log
```
