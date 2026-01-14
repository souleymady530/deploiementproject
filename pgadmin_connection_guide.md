# Guide de Connexion pgAdmin

> [!IMPORTANT]
> **Résolution Rapide :** Si vous ne voyez pas le serveur "PostgreSQL Container" à gauche, suivez les étapes de **Configuration Manuelle** ci-dessous. C'est la méthode la plus fiable.

## 1. Accès à pgAdmin
Ouvrez votre navigateur sur [http://localhost:5050](http://localhost:5050)
- **Email** : `admin@admin.com`
- **Mot de passe** : `admin`

## 2. Configuration manuelle (si nécessaire)
Si "PostgreSQL Container" n'apparaît pas dans l'arbre à gauche :
1. Faites un clic droit sur **Servers** > **Register** > **Server...**
2. Dans l'onglet **General** :
   - **Name** : `PostgreSQL Local`
3. Dans l'onglet **Connection** :
   - **Host name/address** : `postgres` (car pgAdmin et Postgres sont dans le même réseau Docker)
   - **Port** : `5432`
   - **Maintenance database** : `postgres`
   - **Username** : `postgres`
   - **Password** : `postgres`
4. Cliquez sur **Save**.

## 3. Vérification des bases
Une fois connecté, vous devriez voir :
- `mydb`
- `sgmao`
- `postgres` (la base par défaut)
