# arCARna — Brief technique pour reconstruction sous Godot 4 + Blender

> Document de handoff destiné à Claude Code.
> Objectif : reconstruire le prototype de course arcade (initialement en Three.js) sur une base robuste et maintenable. Style cible : **Asphalt** — arcade à 100 %, sensation de vitesse exagérée, drift permissif, nitro spectaculaire.
> Lecteur supposé compétent (Godot 4.x, Blender, pipeline glTF, GDScript).

---

## 1. Piliers de gameplay (les notions non négociables)

Tout le reste découle de ces principes. Si un choix technique entre en conflit avec un pilier, c'est le pilier qui gagne.

1. **Arcade = exagération + pardon.** Pas de physique réaliste. La voiture colle à la route, ne capote jamais, récupère vite. Le « réalisme » tue la sensation Asphalt. On simule, on ne simule pas.
2. **La sensation de vitesse prime sur la vitesse réelle.** Elle se fabrique avec : FOV qui s'élargit avec la vitesse, lignes de vitesse, motion blur léger, flou des bords, défilement rapide du décor proche, screen shake subtil. Une voiture à 60 u/s bien « habillée » paraît plus rapide qu'une à 120 u/s sans effets.
3. **Boucle de risque/récompense.** Le joueur doit être tenté de prendre des risques : frôler le trafic, drifter long, rester plein gaz dans les virages. Chaque risque alimente une ressource (nitro / combo) qui alimente la vitesse, qui ré-augmente le risque. C'est le moteur d'engagement.
4. **Économie du nitro.** Le nitro est la devise centrale. On le gagne par le **drift**, les **near-miss** (frôler une voiture sans la toucher), les **sauts** et la **collecte d'anneaux**. On le dépense pour un boost de vitesse + FOV + effets. Jauge segmentée (ex. 3 segments) → on peut lâcher un boost partiel ou attendre le « perfect nitro ».
5. **Le drift est central, pas accessoire.** Frein à main / contre-braquage → la voiture glisse, le cap se découple de la trajectoire, le nitro se charge. Le drift doit être facile à déclencher, gratifiant visuellement (fumée, traces de gomme) et récompensé mécaniquement.
6. **Feedback immédiat et juteux (« juice »).** Chaque action a un retour multi-sensoriel : son moteur qui monte, particules, flash, vibration manette, hit-stop léger sur crash, pop de score. Le « game feel » se joue dans ces 50 ms.
7. **Lisibilité.** Malgré le chaos visuel, le joueur doit toujours lire sa voie, le trafic et le prochain virage. Trafic contrasté, route bien délimitée, anticipation de la courbe via la caméra.

---

## 2. Pourquoi Godot + Blender (et ce qu'il NE faut PAS faire)

- **Godot 4.x** apporte ce qui manquait au prototype Three.js : arbre de scène, signaux, `_physics_process` à pas fixe, `InputMap` (clavier + manette gratuits), `AudioStreamPlayer3D` avec `pitch_scale`, `GPUParticles3D`, `WorldEnvironment` (glow/fog/tonemap), export multiplateforme.
- **Piège majeur à éviter : `VehicleBody3D`.** C'est un modèle de simulation (suspension, pneus, transferts de masse). Excellent pour un sim, **catastrophique pour de l'arcade** : difficile à régler, comportement imprévisible, capote, sous-vire. **On ne l'utilise pas.**
- **Approche retenue : contrôleur arcade scripté** sur un `CharacterBody3D` (ou `RigidBody3D` en mode custom, mais `CharacterBody3D` est plus simple et plus prévisible). On gère nous-mêmes vitesse, cap, grip et glisse. C'est exactement comme ça que les vrais arcade racers fonctionnent.
- **Blender** sert au modeling (voiture, trafic, props, éventuellement tronçons de piste) et à l'export **glTF 2.0** vers Godot. Pas de moteur physique côté Blender ; on n'exporte que géométrie + matériaux + origines bien placées.

---

## 3. Architecture Godot — arborescence de scène

```
Main (Node3D)
├── World (Node3D)
│   ├── Track (Path3D)                # spline maîtresse de la piste
│   │   └── RoadMesh (MeshInstance3D / CSGPolygon3D le long du Path)
│   ├── Environment (Node3D)          # skyline, foule, props instanciés
│   ├── TrafficManager (Node3D + script)
│   └── PickupManager (Node3D + script)   # anneaux nitro
├── Player (CharacterBody3D)          # = la voiture, scène séparée Player.tscn
│   ├── CarMesh (Node3D)              # le glTF importé de Blender
│   │   ├── Body
│   │   ├── Wheel_FL / FR / RL / RR   # objets séparés, origines au centre de roue
│   │   └── Spoiler
│   ├── CollisionShape3D              # BoxShape3D simple (pas la mesh détaillée)
│   ├── GroundRay (RayCast3D)         # vers le bas, pour coller au sol
│   ├── CameraRig (Node3D)
│   │   └── SpringArm3D
│   │       └── Camera3D
│   ├── NitroParticles (GPUParticles3D)
│   ├── DriftSmoke_L / R (GPUParticles3D)
│   ├── EngineSound (AudioStreamPlayer3D)
│   └── NitroSound (AudioStreamPlayer3D)
├── HUD (CanvasLayer)
│   ├── Speedometer / Score / ComboLabel / NitroBar / LapLabel / Timer
│   └── SpeedLines (TextureRect + shader, ou GPUParticles2D)
├── WorldEnvironment (WorldEnvironment)   # glow, fog, tonemap, ajustement FOV
└── GameManager (Node + script autoload)  # état global : score, tour, chrono, signaux
```

- **`GameManager` en autoload (singleton).** Centralise score, combo, tour, chrono, état (menu/course/fin) et émet des signaux (`combo_changed`, `lap_completed`, `nitro_changed`). Le HUD s'abonne aux signaux → zéro couplage direct.
- **Player en scène autonome** (`Player.tscn`) réutilisable et testable isolément.
- **Caméra via `SpringArm3D`** : gère automatiquement l'évitement de collision et le lissage. On module sa longueur et le FOV de la `Camera3D` en fonction de la vitesse.

---

## 4. Le cœur : contrôleur de voiture arcade (squelette GDScript)

C'est le morceau le plus important. Modèle « fake physics » : une vitesse avant scalaire + un cap (heading) + un grip qui aligne plus ou moins vite la vélocité réelle sur le cap. Le drift = baisse temporaire du grip.

```gdscript
extends CharacterBody3D

# --- Paramètres exposés pour tuning rapide dans l'inspecteur ---
@export var max_speed: float = 60.0
@export var nitro_speed: float = 95.0
@export var accel: float = 35.0
@export var brake_force: float = 70.0
@export var coast_drag: float = 12.0        # décélération roue libre
@export var turn_rate: float = 2.4          # rad/s à pleine vitesse
@export var grip: float = 7.0               # alignement vélocité→cap (haut = adhérent)
@export var drift_grip: float = 1.6         # grip réduit pendant le drift
@export var gravity: float = 30.0
@export var nitro_boost_mult: float = 1.0   # accel supplémentaire sous nitro

var forward_speed: float = 0.0
var is_drifting: bool = false

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var braking := Input.get_action_strength("brake")
	# axe -1 (droite) .. +1 (gauche), à inverser selon convention
	var steer := Input.get_axis("steer_right", "steer_left")
	var handbrake := Input.is_action_pressed("drift")
	var nitro_on := Input.is_action_pressed("nitro") and GameManager.nitro > 0.0

	var target_max := nitro_speed if nitro_on else max_speed

	# 1) Vitesse avant scalaire
	if throttle > 0.0:
		forward_speed = move_toward(forward_speed, target_max, accel * (1.0 + (nitro_boost_mult if nitro_on else 0.0)) * delta)
	elif braking > 0.0:
		forward_speed = move_toward(forward_speed, 0.0, brake_force * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, coast_drag * delta)
	# bridage doux si on repasse sous le max après le nitro
	forward_speed = min(forward_speed, target_max)

	# 2) Rotation du cap — d'autant plus marquée qu'on roule vite
	var speed_factor := clamp(forward_speed / max_speed, 0.0, 1.0)
	var steer_amount := steer * turn_rate * speed_factor
	if handbrake and forward_speed > 5.0:
		steer_amount *= 1.6        # le frein à main fait tourner plus fort
	rotation.y += steer_amount * delta

	# 3) Drift : on glisse quand on braque fort + vite, ou frein à main
	is_drifting = handbrake and forward_speed > 8.0 \
		or (abs(steer) > 0.6 and forward_speed > max_speed * 0.6)
	var current_grip := drift_grip if is_drifting else grip

	# 4) Direction visée (cap) vs vélocité réelle, alignement progressif = grip
	var heading := -transform.basis.z          # avant local
	var desired_vel := heading * forward_speed
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	horiz_vel = horiz_vel.lerp(desired_vel, clamp(current_grip * delta, 0.0, 1.0))

	# 5) Gravité / collage au sol
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z
	move_and_slide()

	# 6) Récompenses : le drift charge le nitro
	if is_drifting:
		GameManager.add_nitro(0.25 * delta)
		# -> émettre fumée, traces de gomme, son de crissement

	# 7) Feedback visuel : roll dans les virages, roues qui tournent, aileron
	$CarMesh.rotation.z = lerp($CarMesh.rotation.z, -steer * 0.12, 8.0 * delta)
```

**Points clés du modèle :**
- `forward_speed` est une **devise scalaire** ; la vélocité réelle (`velocity`) ne s'y aligne qu'au rythme du `grip`. Tout le « feel » se règle avec `grip` vs `drift_grip`.
- Le drift est volontairement **facile à déclencher** et **auto-récompensé** (charge nitro).
- Aucun couple, aucune masse, aucune suspension. C'est voulu.
- Tuning : commence par `grip=7`, `drift_grip=1.6`, `turn_rate=2.4`, puis ajuste à la main jusqu'à ce que ça « sente » bon. C'est de l'itération, pas du calcul.

---

## 5. Caméra (fabrique de vitesse)

```gdscript
# Sur le CameraRig / script de la caméra
@export var base_fov: float = 70.0
@export var max_fov: float = 92.0
@export var base_arm: float = 6.0
@export var max_arm: float = 8.5

func _process(delta):
	var s := clamp(player.forward_speed / player.max_speed, 0.0, 1.0)
	var boost := 1.3 if player_nitro_active else 1.0
	camera.fov = lerp(camera.fov, base_fov + (max_fov - base_fov) * s * boost, 4.0 * delta)
	spring_arm.spring_length = lerp(spring_arm.spring_length, base_arm + (max_arm - base_arm) * s, 4.0 * delta)
	# léger lookahead vers le prochain virage : viser un point en avant sur le Path3D
```

- **FOV dynamique** = l'effet de vitesse n°1. Élargir sous nitro renforce le coup de boost.
- **SpringArm3D** recule légèrement et lisse les secousses.
- **Lookahead** : viser un point en avant sur la spline pour anticiper les courbes (lisibilité).
- Screen shake : petit bruit Perlin sur la position de la caméra, amplitude proportionnelle au nitro et aux impacts.

---

## 6. Systèmes de jeu (à implémenter dans GameManager + scripts dédiés)

- **Nitro** : `var nitro: float` (0..1, ou en segments). Gagné par drift, near-miss, sauts, anneaux. Dépensé en boost. Signal `nitro_changed`.
- **Combo / multiplicateur** : chaque pickup ou near-miss incrémente le combo ; un timer le remet à zéro s'il n'est pas entretenu ; un crash le casse. Le score gagné = base × combo.
- **Near-miss** : `Area3D` autour de la voiture ; si une voiture de trafic entre dans la zone mais pas dans la `CollisionShape3D` → bonus nitro + pop visuel « NEAR MISS ».
- **Sauts / rampes** : `RigidBody3D` désactivé, on lit `is_on_floor()` ; airtime → bonus nitro à l'atterrissage, atterrissage propre = combo.
- **Tours / chrono** : `Area3D` ligne d'arrivée le long du `Path3D` ; à chaque passage → `lap_completed`. Chrono au pas physique.
- **Crash** : hit-stop (Engine.time_scale bref), grosse secousse, perte combo, son grave. Jamais de game over instantané — on punit, on ne stoppe pas.

---

## 7. Piste et environnement

- **Spline maîtresse : `Path3D`.** La piste suit une courbe. Deux options pour la géométrie :
  - **CSGPolygon3D en mode PATH** : extrude un profil 2D (la coupe de la route) le long du `Path3D`. Rapide à prototyper, parfait pour un ruban de route continu.
  - **Mesh bakée depuis Blender** : tronçons modulaires (`track_straight.glb`, `track_curve_L.glb`…) instanciés bout à bout. Plus joli, plus lourd à mettre en place.
  - Recommandé : **CSGPolygon3D** pour la v1 (itération rapide), passage en mesh bakée seulement si besoin de détail.
- **Le `Path3D` sert double emploi** : géométrie + référence pour l'IA du trafic + lookahead caméra + détection de progression (offset le long de la courbe via `Curve3D`).
- **Environnement** : skyline, foule, lampadaires → `MultiMeshInstance3D` pour instancier des milliers d'éléments sans coût (le prototype Three.js les créait un par un, à éviter).
- **WorldEnvironment** : fog exponentiel pour la profondeur, glow activé (néons, phares, nitro), tonemap (Filmic ou ACES), ajustement de couleur nocturne.

---

## 8. Trafic / IA (simple et robuste)

- Voitures de trafic = scène `TrafficCar.tscn`, spawnées par `TrafficManager` en avant du joueur, recyclées (object pooling — réutiliser, ne jamais `queue_free` en boucle).
- Comportement minimal : avancer le long du `Path3D` à vitesse fixe, légère dérive latérale aléatoire entre les voies. Pas de pathfinding — la spline EST le chemin.
- Voies discrètes : 3 positions latérales calculées par décalage perpendiculaire au `Path3D`.
- Contraste visuel obligatoire (feux arrière rouges vifs) pour la lisibilité.

---

## 9. Effets visuels (le « juice »)

- **Nitro** : `GPUParticles3D` à l'échappement (boules orange/jaune additives) + cône de flamme + `WorldEnvironment` glow qui pulse + flash plein écran (TextureRect en `CanvasLayer`).
- **Fumée de drift** : `GPUParticles3D` aux roues arrière quand `is_drifting`, + **traces de gomme** persistantes (decals ou trail de mesh sur le sol).
- **Lignes de vitesse** : shader plein écran (radial, intensité = vitesse) bien plus propre que des meshes 3D. Renforcé sous nitro.
- **Motion blur léger** : via shader d'écran custom (compositor / post-process Godot 4) — dosé, sinon illisible.
- **Chromatic aberration** subtile sous nitro pour le punch.
- **Hit-stop** sur crash : `Engine.time_scale = 0.05` pendant ~80 ms puis retour à 1.0.

---

## 10. Audio

- **Moteur** : un `AudioStreamPlayer3D` en boucle, `pitch_scale` piloté par `forward_speed` et le rapport simulé (ramper le pitch, ne pas le claquer). Idéalement un sample de moteur looped ; à défaut, un bruit synthétisé.
- **Nitro** : couche de bruit filtré (whoosh) qui fade-in pendant le boost.
- **Crissement de pneus** pendant le drift.
- **SFX** : pickup (cloche montante selon le combo), tour bouclé, crash (impact grave), near-miss (swoosh).
- Utiliser des **bus audio** (Master / SFX / Engine / Music) pour mixer proprement.

---

## 11. Input (clavier + manette gratuits)

Définir l'`InputMap` dans les réglages projet :

| Action | Clavier (QWERTY/AZERTY) | Manette |
|---|---|---|
| `accelerate` | ↑ / W / Z | RT (gâchette droite) |
| `brake` | ↓ / S | LT |
| `steer_left` | ← / A / Q | stick gauche X− |
| `steer_right` | → / D | stick gauche X+ |
| `nitro` | Espace / Maj | A / X |
| `drift` | Ctrl gauche | B / O |

- `Input.get_axis()` pour la direction (gère analogique manette automatiquement).
- `Input.get_action_strength()` pour gaz/frein analogiques aux gâchettes.
- Vibration manette via `Input.start_joy_vibration()` sur boost et crash.

---

## 12. Pipeline Blender → Godot (glTF)

**Modélisation voiture :**
- Low-poly stylisé (style arcade, pas de réalisme), formes lisibles.
- **Roues = objets séparés**, origine (`Object > Set Origin > Origin to Center of Mass`) **exactement au centre de l'essieu**, sinon elles tournent de travers dans Godot.
- Nommer clairement : `Body`, `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`, `Spoiler`. Ces noms deviennent des `Node3D` enfants dans Godot → on les anime par script.
- Parenter les roues et l'aileron au `Body` (ou les garder au même niveau sous une `Empty` racine).

**Conventions impératives avant export :**
- **Échelle : 1 unité Blender = 1 mètre Godot.** `Object > Apply > All Transforms` (Ctrl+A) sur tout, sinon échelles/rotations parasites.
- **Axes** : Blender = Z up, Godot = Y up. L'exportateur glTF gère la conversion ; vérifier l'orientation après import (l'avant de la voiture doit pointer vers `-Z` en local dans Godot).
- **Matériaux** : Principled BSDF uniquement. Couleurs/PBR simples. Émissif pour phares/feux/néons (récupéré par le glow Godot).

**Collisions :**
- **Ne pas** utiliser la mesh détaillée comme collision. Créer une boîte simple, ou un objet `-col` (collision triangle) / `-convcol` (collision convexe) : Godot génère automatiquement la `CollisionShape3D` à l'import depuis ces suffixes. Pour une voiture arcade, une simple `BoxShape3D` posée à la main dans Godot suffit largement.

**Export glTF 2.0 (.glb) :**
- Format **glTF Binary (.glb)** (un seul fichier).
- Cocher : `Apply Modifiers`, `+Y Up`, inclure matériaux et textures.
- Ranger les `.glb` dans `res://assets/models/`. Godot ré-importe automatiquement à chaque modif du fichier.
- Dans Godot, on instancie le `.glb`, on l'ouvre éventuellement en scène héritée pour ajouter collision/scripts sans casser le ré-import.

---

## 13. Structure de projet recommandée

```
res://
├── scenes/
│   ├── Main.tscn
│   ├── Player.tscn
│   ├── TrafficCar.tscn
│   ├── NitroPickup.tscn
│   └── HUD.tscn
├── scripts/
│   ├── player.gd
│   ├── camera_rig.gd
│   ├── traffic_manager.gd
│   ├── pickup.gd
│   └── game_manager.gd        # autoload
├── assets/
│   ├── models/                # .glb depuis Blender
│   ├── textures/
│   ├── audio/
│   └── shaders/               # speed_lines.gdshader, motion_blur, etc.
└── project.godot
```

---

## 14. Roadmap (jalons incrémentaux pour Claude Code)

Construire et tester **dans cet ordre** — chaque jalon doit être jouable avant de passer au suivant.

1. **Contrôleur arcade nu** : un cube sur un plan plat infini, conduite/drift/grip réglables. Valider le feel AVANT tout le reste. C'est 80 % du jeu.
2. **Caméra dynamique** : SpringArm + FOV vitesse + lookahead.
3. **Piste spline** : `Path3D` + `CSGPolygon3D`, bordures, ligne de départ/arrivée.
4. **Voiture Blender** : remplacer le cube par le `.glb`, roues qui tournent, roll dans les virages.
5. **Nitro + boost + jauge HUD** : économie complète, effets de boost.
6. **Pickups + combo + score** : anneaux, multiplicateur, signaux HUD.
7. **Trafic** : spawn/pool, collisions, near-miss.
8. **Drift juice** : fumée, traces de gomme, crissement.
9. **Effets écran** : speed lines, glow, motion blur, hit-stop.
10. **Audio complet** : moteur pitch-scalé, nitro, SFX.
11. **Tours / chrono / écran de fin / rejouer.**
12. **Manette + vibration + export.**

---

## 15. Pièges Godot connus (à signaler à Claude Code)

- **Ne PAS utiliser `VehicleBody3D`** (cf. §2). Contrôleur scripté uniquement.
- Toute la physique dans **`_physics_process`** (pas fixe), jamais `_process`, pour un comportement stable.
- `move_and_slide()` n'attend **pas** de paramètre vitesse en Godot 4 : il utilise la propriété `velocity` du `CharacterBody3D`.
- Instancier le décor en masse via **`MultiMeshInstance3D`**, pas en boucle de nodes (le proto Three.js créait tout un par un → ne pas reproduire).
- **Object pooling** pour trafic et particules : réutiliser les instances, éviter `instantiate()`/`queue_free()` en continu.
- Glow/émissif : activer dans `WorldEnvironment` ET mettre `emission` sur les matériaux concernés, sinon pas d'effet.
- Vérifier l'orientation avant/-Z de la voiture après import glTF ; au besoin pivoter la `CarMesh`, pas le `CharacterBody3D`.
- Pour l'audio moteur, **ramper** `pitch_scale` (lerp), jamais l'assigner brutalement (clics audibles).

---

## 16. Prompt de démarrage suggéré pour Claude Code

> « Crée un projet Godot 4.x de course arcade nommé arCARna. Commence par le jalon 1 du brief : un contrôleur de voiture arcade scripté sur `CharacterBody3D` (PAS `VehicleBody3D`), avec vitesse avant scalaire, cap découplé via un paramètre de grip, drift au frein à main qui réduit le grip et charge une jauge de nitro. Plan plat infini, cube temporaire à la place de la voiture, tous les paramètres exposés en `@export` pour tuning. Configure l'`InputMap` (clavier + manette). Rends-le jouable et confirme avant de passer au jalon suivant. »

---

*Fin du brief. Itère jalon par jalon ; valide le feel à chaque étape avant d'ajouter du contenu.*
