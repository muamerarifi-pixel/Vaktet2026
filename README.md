# Vaktet – Kohët e namazit në Kosovë

Aplikacion web (PWA) për kohët e namazit në qytetet e Kosovës. Punon në telefon dhe laptop, dhe pa internet pasi hapet një herë.

**Live:** https://vaktet-kosove-1.vercel.app

## Çfarë ka
- **Namazi i ardhshëm** me numërim mbrapsht të madh e të qartë.
- **Qielli që ndryshon sipas vaktit** – natë me yje (Jacia), agim (Sabahu), mëngjes, mesditë (Dreka), pasdite e artë (Ikindia), muzg (Akshami). Dielli lëviz nga lindja në perëndim, pastaj hëna deri në mëngjes.
- **Kohët e ndaluara** (lindja, zeniti, perëndimi) – karta bëhet e kuqe me paralajmërim.
- **Fshih vaktet** – mbetet vetëm karta, e qendërzuar në mes të ekranit, me dy këshilla të përditshme (për jetën dhe si musliman).
- **Alarmi i sugjeruar për sabah** (15/30/45/60 min para lindjes së diellit).
- **Tabela mujore**, data hixhri (me korrigjim ±2 ditë), 19 qytete.
- **Pamje e çelët / e errët / automatike**; ekrani i hapjes është i errët, që të mos verbojë natën.
- Funksionon **pa internet** (service worker) dhe instalohet si aplikacion.

## Skedarët
| Skedari | Çfarë bën |
|---|---|
| `index.html` | Faqja |
| `styles.css` | Pamja, ngjyrat e qiellit, pamja e errët |
| `app.js` | Logjika: kohët, numërimi, qielli, cilësimet |
| `data.js` | Kohët e Takvimit të BIK për çdo ditë të vitit |
| `tips.js` | Këshillat e përditshme |
| `sw.js` | Puna pa internet |
| `manifest.webmanifest` | Instalimi si aplikacion |
| `vercel.json` | Rregullat e cache-it për Vercel |
| `fonts/`, `icons/` | Shkronja Figtree (licenca OFL) dhe ikonat |

## Burimi i kohëve
Kohët janë nga Takvimi zyrtar i Bashkësisë Islame të Kosovës (BIK), 2026:
https://dituriaislame.com/wp-content/uploads/2026/01/takvimi2026vaktet.pdf

- Takvimi i BIK përsëritet sipas datës kalendarike çdo vit, prandaj tabela e ruajtur në `data.js` vlen edhe për vitet në vijim.
- Kohët ruhen në kohë standarde (UTC+1); aplikacioni shton vetë orën verore sipas zonës kohore `Europe/Belgrade` (që përdor Kosova), kështu që ndërrimi i orës mbetet i saktë në çdo vit.
- 29 shkurti (vitet e brishta) përdor kohët e 28 shkurtit.
- Dallimet e qyteteve sipas Takvimit: Prishtina, Ferizaj, Gjilani, Podujeva, Vushtrria −1 min; Sharri (Dragash) +2 min. Qytetet e tjera përdorin kohët bazë.

## Publikimi në Vercel
1. Hapni vercel.com → Add New → Project → importoni këtë repository nga GitHub.
2. Framework Preset: **Other**. Nuk ka build – është faqe statike.
3. Deploy.

Për ta provuar në kompjuter: `npx serve .` dhe hapni adresën që shfaqet.

Për ta instaluar në telefon: hapni faqen → menyja e shfletuesit → "Shto në ekranin kryesor" / "Install app".

## Përditësimi
Nëse ndryshoni ndonjë skedar, rrisni versionin `CACHE` në `sw.js` (p.sh. `vaktet-v15`) që pajisjet ta marrin versionin e ri.
