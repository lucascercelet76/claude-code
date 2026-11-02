# Atelier Photo

Application iOS de retouche photo (SwiftUI, iOS 17+, iPhone et iPad).

## Fonctionnalités

| Outil | Ce qu’il fait |
|---|---|
| **Calques** | Photos, dessins, textes et formes empilés. Ordre, visibilité, opacité, modes de fusion (Produit, Incrustation…), dupliquer, supprimer |
| **Réglages** | Luminosité, exposition, contraste, saturation, température, netteté, vignette |
| **Filtres** | Noir, Mono, Sépia, Vintage, Chrome, Délavé, Instant, Pop, Flou, avec un curseur d’intensité |
| **Esquisse** | Transforme une photo en dessin : Crayon, Crayons de couleur, Fusain, Contours, BD. Curseurs « épaisseur du trait » et « mélange photo » |
| **Détourer** | Supprime l’arrière-plan avec l’IA de l’appareil (Vision, sans connexion) ou copie le sujet sur un nouveau calque. Gomme pour affiner, fond uni à ajouter |
| **Formes** | Rectangle, rectangle arrondi, ellipse, triangle, étoile, polygone, cœur, ligne, flèche. Remplissage, contour, épaisseur, taille, arrondi, nombre de branches |
| **Texte** | Police, taille, couleur, gras, ombre |
| **Pinceau / Gomme** | Dessin au doigt ou à l’Apple Pencil. La gomme efface aussi les photos |
| **Recadrer** | Formats Libre, Original, 1:1, 4:3, 3:4, 16:9 et 9:16. Rotation à 90° et miroir |
| **Annuler / Rétablir** | Jusqu’à 40 étapes |
| **Exporter** | PNG (avec transparence) ou JPEG, vers Photos ou via le partage |

Sur la toile, avec l’outil « Déplacer », le calque sélectionné se déplace en le faisant glisser, se redimensionne en pinçant et pivote avec deux doigts.

## Lancer l’app

Il faut un Mac avec **Xcode 16** ou plus récent.

1. Ouvre `AtelierPhoto.xcodeproj`.
2. Sélectionne la cible **AtelierPhoto**, onglet *Signing & Capabilities*, puis choisis ton équipe (un compte Apple gratuit suffit pour tester sur ton propre iPhone).
3. Si Xcode le demande, change l’identifiant `com.example.AtelierPhoto` pour un identifiant unique.
4. Choisis ton iPhone (ou un simulateur) et appuie sur ▶︎.

> Le détourage automatique utilise `VNGenerateForegroundInstanceMaskRequest` (iOS 17). Sur le simulateur, cette requête n’est pas toujours disponible : l’app utilise alors la détection de personnes uniquement. Teste le détourage sur un vrai appareil.

## Organisation du code

```
AtelierPhoto/
├── AtelierPhotoApp.swift        Point d’entrée
├── Models/                      Calques, filtres, formes
├── Processing/
│   ├── ImageProcessor.swift     Réglages, filtres, esquisses (Core Image), recadrage
│   └── BackgroundRemover.swift  Détourage (Vision)
├── ViewModel/EditorViewModel.swift  État du document, historique, outils
└── Views/                       Écran d’accueil, éditeur, toile, panneaux, recadrage, export
```

Le projet utilise les dossiers synchronisés de Xcode 16 : un fichier `.swift` ajouté dans `AtelierPhoto/` est inclus automatiquement dans la compilation.
