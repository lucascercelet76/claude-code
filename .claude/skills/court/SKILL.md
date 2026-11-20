---
name: court
description: Fait juger une idée (business, produit, prix, projet) par un tribunal de sous-agents — procureur, défense, jury de 12 personas qui votent à huis clos, puis un juge qui rend le verdict dans VERDICT.md. À utiliser quand l'utilisateur tape /court, demande « mon idée est-elle bonne ? », veut un avis honnête plutôt que des compliments, ou veut stress-tester une idée. Option --quick pour un procès court à 5 jurés.
argument-hint: "[--quick] <ton idée>"
---

# /court — le tribunal des idées

But : donner un avis **honnête** sur une idée, pas « Excellente idée ! ». Chaque rôle est un
sous-agent séparé, pour que personne ne soit influencé par les autres.

## 0. Le dossier

- L'idée est dans les arguments. Si `--quick` est présent, retire-le et passe en mode rapide.
- Si l'idée manque ou est trop vague pour être jugée (pas de cible, pas de prix, pas de
  contexte), pose **au plus 3 questions** courtes, puis continue.
- Rédige un **dossier** de 5 à 10 lignes : l'idée, la cible, le prix ou modèle économique,
  ce qui existe déjà (ventes, clients, temps disponible), ce que l'utilisateur envisage de
  faire (ex. quitter son emploi). N'invente aucun chiffre : écris « inconnu ».

## 1. L'audience (2 sous-agents en parallèle)

Lance en parallèle, avec l'outil Agent, deux sous-agents qui reçoivent seulement le dossier :

- **Procureur** : cherche les raisons pour lesquelles l'idée va échouer (marché saturé,
  prix, marges, demande, concurrence, temps, risques juridiques). 3 à 5 charges, chacune
  courte et concrète, classées de la plus grave à la moins grave.
- **Défense** : cherche les meilleures raisons pour lesquelles elle peut réussir, en
  s'appuyant sur les faits du dossier (ventes déjà faites, coûts bas, demande). 3 à 5
  arguments, même format.

Consigne commune : rester factuel, ne rien inventer, signaler ce qui est une supposition.

## 2. Le jury (12 sous-agents en parallèle, à huis clos)

Lance **en un seul message** 12 sous-agents. Chacun reçoit le dossier + les charges +
la défense, et **un seul** persona. Aucun ne voit le vote des autres.

| # | Juré | Regarde surtout |
|---|------|-----------------|
| 1 | Comptable | marges, coûts cachés, seuil de rentabilité |
| 2 | Client cible | « est-ce que je paierais ce prix ? » |
| 3 | Concurrent | facilité à copier, ce qu'il ferait pour écraser l'idée |
| 4 | Jeune consommateur | envie, tendance, partage sur les réseaux |
| 5 | Investisseur | potentiel de croissance, risque |
| 6 | Vendeur / commercial | facilité à vendre, objections |
| 7 | Technicien / fabricant | faisabilité, logistique, qualité |
| 8 | Analyste de marché | taille et tendance du marché |
| 9 | Senior prudent | sécurité financière, ce qu'on risque de perdre |
| 10 | Entrepreneur expérimenté | exécution, temps, erreurs classiques |
| 11 | Designer / marketeur | marque, différenciation, image |
| 12 | Juriste | statut, réglementation, propriété intellectuelle |

Chaque juré répond **exactement** dans ce format :

```
VOTE: COUPABLE | NON COUPABLE
RAISON: <une phrase, à la première personne, dans la voix du persona>
POUR ME FAIRE CHANGER D'AVIS: <une action concrète>
```

COUPABLE = l'idée, telle quelle, ne devrait pas être lancée. NON COUPABLE = elle mérite
d'être lancée (ou testée) telle quelle.

## 3. Le verdict

Toi (le juge), sans nouvel agent :

1. Compte les votes. Majorité de COUPABLE (7+) = **coupable** ; 6/6 = **jury partagé**.
2. Écris `VERDICT.md` dans le dossier courant :

```markdown
# Verdict — <idée en une ligne>

**<N> coupable · <M> non coupable** → <COUPABLE | NON COUPABLE | JURY PARTAGÉ>

## L'accusation
- ...
## La défense
- ...
## Ce qu'a dit le jury
| Juré | Vote | Raison |
|------|------|--------|
...
## Pour retourner les votes
- [ ] <les 2 à 4 actions les plus citées, concrètes et testables>

## Avis du juge
<3 à 5 phrases franches : faut-il y aller, tester d'abord, ou abandonner, et pourquoi.>
```

3. Dans le chat, donne seulement : le score, les 2 raisons qui ont le plus pesé, les actions
   « pour retourner les votes », et le chemin de `VERDICT.md`.

## Mode `--quick`

- Pas de procureur ni de défense en sous-agents : écris toi-même 3 charges et 3 arguments.
- Jury de **5** jurés : Comptable, Client cible, Concurrent, Investisseur, Entrepreneur
  expérimenté. Majorité = 3.
- Même format de `VERDICT.md`.

## Règles

- Ne flatte jamais. Si l'idée est bonne, dis-le avec des raisons, pas des superlatifs.
- N'invente ni chiffres ni sources. Une supposition est marquée « (supposition) ».
- Réponds dans la langue de l'utilisateur.
