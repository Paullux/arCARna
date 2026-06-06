# arCARna v0.2.0 🏎️🌃

> **Retro Gaming (F-Zero / Wipe Out) + Outils modernes**

Course arcade néon sous Godot 4.6.3. Téléchargez l'exécutable autonome ci-dessous (Windows ou Linux), décompressez, lancez — aucune installation requise.

## ⬇️ Téléchargement
- **Windows** : `arCARna-windows.zip` → `arCARna.exe`
- **Linux** : `arCARna-linux.zip` → `arCARna.x86_64` (`chmod +x` si besoin)

## 🎮 Contrôles
| Action | Clavier | Manette |
|---|---|---|
| Accélérer | ↑ / W / Z | RT |
| Freiner / Reculer | ↓ / S | LT |
| Tourner | ← → / A D / Q D | Stick gauche |
| Nitro | Espace / Maj | A / X |
| Drift | Ctrl gauche | B / O |
| Rejouer (après game over) | Espace | — |

---

## ✨ Nouveautés de cette version

### 🚦 Départ de course
- **Grille de départ** : les adversaires sont alignés derrière la ligne, **figés pendant le décompte**, puis s'élancent au **START**.
- **Décompte 3D** (3 → 2 → 1 → START) en modèles lumineux façon feux de F1, **suivant la caméra**, avec **bip** sonore.

### 🏁 Conduite & limites de piste
- **Voiture plaquée au sol** : fini les décollages/enfoncements au contact du trafic (collage au sol par rayon dédié).
- **Barrières néon solides** : impossible de traverser les néons — la voiture **rebondit** vers la piste (étincelles + perte d'énergie).
- **Passage du stand ouvert** : le néon est troué devant la zone de recharge pour pouvoir y entrer.
- **Sortie de piste = game over** : tomber hors du circuit déclenche l'explosion.

### 💥 Game over typé
L'écran de fin indique désormais **la cause** :
- ⛽ **Panne sèche** (plus de carburant)
- 💥 **Choc de trop** (voiture détruite)
- 🚧 **Sortie de piste** (hors circuit)

### 🖥️ Interface
- **Position du joueur** affichée dans le HUD (`P x/13`).
- **Splash de démarrage** aux couleurs du jeu (bandeau).

### 🎨 Visuel
- **Trafic multicolore** : nouveau shader qui distingue le **noir des vitres** des **couleurs vives** de carrosserie — chaque adversaire a sa teinte, vitres noires réalistes.

### 🔊 Audio
- **Radio embarquée** : 3 musiques cyberpunk en lecture aléatoire (sans répétition immédiate).
- **Effets sonores** dédiés (moteur, nitro, drift, impact, explosion, recharge, frôlement) sur des bus séparés Musique / SFX.

---

## 🛠️ Détails techniques
- Moteur : **Godot 4.6.3**, GDScript, `CharacterBody3D` (physique arcade scriptée, pas de `VehicleBody3D`).
- Collision de piste et barrières **générées automatiquement** depuis la géométrie Blender.
- Builds **Windows + Linux** produits automatiquement par GitHub Actions.

## ⚠️ Connu / à venir
- Les modèles 3D du décompte sont volumineux (textures haute résolution) — optimisation prévue.
- Équilibrage de la vitesse du trafic et du ressenti de rebond à affiner.

**Licence : GPLv3**
