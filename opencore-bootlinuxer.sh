#!/usr/bin/env bash
# OpenCore Bootlinuxer by BecabDev
# Made with love in Cannes

set -uo pipefail

BRAND="OpenCore Bootlinuxer by BecabDev"
STATE_DIR=/var/lib/opencore-bootlinuxer
STATE_FILE=$STATE_DIR/state.env
BACKUP_DIR=$STATE_DIR/backup
HOOK=/etc/grub.d/99_opencore

LANG_UI=""; ESP=""; BOOT_EXISTED=0; ORIG_BOOTORDER=""; OC_BOOTNUM=""; COMPAT=0; GRUBDIR=""
GRUB_CFG=""; NO_SAVE=0
UI_RESULT=""

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
TUI="$WORK/tui.py"

C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[1m'; C_0=$'\e[0m'

#translations
declare -A FR EN
def() { FR[$1]=$2; EN[$1]=$3; }
t() {
  local k=$1 fmt; shift
  if [ "$LANG_UI" = en ]; then fmt=${EN[$k]-$k}; else fmt=${FR[$k]-$k}; fi
  # shellcheck disable sc2059
  printf -- "$fmt" "$@"
}

def yes        "Oui" "Yes"
def no         "Non" "No"
def btn_ok     "Ok" "Ok"
def btn_cancel "Annuler" "Cancel"
def hint_menu  "Haut/bas : naviguer   Entrée/clic : valider   Echap : quitter" \
               "Up/Down: move   Enter/click: select   Escape: quit"
def hint_check "Haut/Bas : naviguer   Espace/clic : cocher   a : tout   Entrée : valider   Échap : annuler" \
               "Up/Down: move   Space/ lick: toggle   a: all   Enter: confirm   Escape: cancel"
def hint_input "Entrée : valider   Échap : annuler" "Enter: confirm   Escape: cancel"
def hint_msg   "Entrée/clic : continuer   Haut/Bas : défiler" "Enter/click: continue   Up/Down: scroll"

def done_title "Terminé" "Done"
def err_title  "Erreur" "Error"
def warn_title "Attention" "Warning"

def lang_sub   "Selectionnez la langue de l'interface.\nChoose the interface language." \
               "Choose the interface language.\nSelectionnez la langue de l'interface."
def lang_title "Langue/language" "Language/Langue"

def menu_title "Menu principal" "Main menu"
def menu_sub   "Partition efi (ESP) : %s" "Efi partition (ESP): %s"
def m1 "Installer/mettre a jour Opencore" "Install / update OpenCore"
def m2 "Customiser le bootloader" "Customize the bootloader"
def m3 "Mode compatibilité : grub dans EFI/BOOT"       "Compatibility mode : Grub in EFI/BOOT"
def m4 "Parametres OpenCore"                           "OpenCore settings"
def m5 "Afficher l'état du bootloader"                 "Show bootloader status"
def m6 "Désinstaller"                                  "Uninstall"
def m7 "Langue / Language"                             "Language / Langue"
def m0 "Quitter"                                       "Quit"

def need_root  "Ce module doit etre lancée avec les droits sudo.\n\nRelancez-le avec :\n\n    sudo ./%s" \
               "This module must be run with superuser rights.\n\nRun it again with:\n\n    sudo  ./%s"
def need_tty   "Ce script nécessite un terminal interactif" "This script needs an interactive terminal"
def need_curses "Le module python curses est requis (paquet python3)" "The Python curses module is required (python3 package)"
def not_uefi   "Système non démarré en UEFI : Opencore ne fonctionne pas sur des systemes legacy" "System not booted in UEFI mode: OpenCore does not work on legacy systems"
def esp_title  "Partition EFI introuvable" "EFI partition not found"
def esp_prompt "Point de montage de la partition EFI :" "Mount point of the EFI partition :"
def esp_nomount "%s n'est pas un point de montage" "%s is not a mount point"

def sb_warn    "Secure Boot est activer : OpenCore ne démarrera pas tant qu'il est pas désactivé dans le firmware.\n\nContinuer quand même ?" \
               "Secure Boot is enabled : OpenCore will not start until it disabled in the firmware.\n\nContinue any way?"
def deps_inst  "Installation des dépendances curl unzip efibootmgr python3" "Installing dependencies curl unzip efibootmgr python3"
def deps_pm    "Gestionnaire de paquets inconnu : installez curl, unzip, efibootmgr et python3" "Unknown package manager: install curl, unzip, efibootmgr and python3"

def old_title  "Installation existante" "Existing installation"
def old_prompt "Une installation d'OpenCore existe déjà (effectuee hors de ce script).\nDossier contenant l'ancien EFI/BOOT à restaurer à la désinstallation (vide = aucun) :" \
               "An OpenCore installation already exists (made outside this script).\nFolder containing the original EFI/BOOT to restore on uninstall (empty = none):"
def dir_nf     "Dossier introuvable : %s" "Folder not found: %s"
def bk_fail    "Sauvegarde impossible" "Backup failed"
def bk_done    "Sauvegarde créée dans %s" "Backup created in %s"
def space_low  "Moins de 30 Mo libres sur l'ESP" "Less than 30 MB free on the ESP"
def to_title   "Délai de démarrage" "Boot timeout"
def to_prompt  "Délai avant démarrage automatique, en secondes (0 = attendre indéfiniment) :" "Delay before automatic boot, in seconds (0 = wait forever):"
def gh_search  "Recherche de la dernieres version d'OpenCore, priere patienter." "Looking for the latest OpenCore release, please wait."
def gh_fail    "GitHub injoignable" "GitHub unrachable"
def oc_ver     "OpenCore %s trouvé" "OpenCore %s found"
def dl_oc_fail "Téléchargement OpenCore impossible." "OpenCore download failed."
def dl_res_fail "Téléchargement des ressources impossible" "Resources download fail"
def cp_fail    "Copie impossible : %s" "Copy failed : %s"
def cfg_exists "Une config.plist existe déja.\nLe régénerer avec les réglages surs pour Linux ?" "A config.plist already exists.\nRegenerate-it with Linux safe settings?"
def fw_fail    "Création de l'entrée firmware impossible, avez vous les droits nécessaires ?" "Could not create the firmware boot entry, do you have the necessary rights ?"
def fw_renamed "Ancienne entrée firmware Boot%s supprimée (renommage)." "Old firmware entry Boot%s removed (renaming)."
def fw_first_t "Ordre de demarrage" "Boot order"
def fw_first_q "Placer %s en premier dans l'ordre de démarrage ?" "Put \"%s\" first in the boot order ?"
def install_ok "OpenCore est installé.\nEntree firmware : %s" "OpenCore is installed.\nFW entry: %s"

def no_oc      "Installez d'abord OpenCore (option 1)" "Install OpenCore first (option 1)"
def no_grub    "Aucun GRUB (grubx64.efi) trouvé dans l'ESP : import impossible (systemd-boot ?)" "No GRUB (grubx64.efi) found in the ESP: cant continue (systemd-boot?)"
def no_cfg     "grub.cfg introuvable dans /boot/grub ou /boot/grub2" "grub.cfg not found in /boot/grub or /boot/grub2"
def multi_t    "Plusieurs GRUB trouvés" "Many GRUB installs found"
def multi_s    "Plusieurs installations de GRUB ont été trouvées dans l'ESP. Laquelle utiliser ?" "Several GRUB installations were found in the ESP. Which one to use?"
def no_stub    "Pas de grub.cfg stub dans %s (GRUB a préfixe embarqué type arch).\nSeule l'entrée principale sera ajoutée" \
               "No stub grub.cfg in %s (embedded prefix GRUB arch like).\nOnly the main entry will be added"
def bls_warn   "Cette distribution utilise les entrées BLS Fedora : la liste sera incomplete" "This distribution uses BLS entries Fedora : the list will be incomplete"
def no_entries "Aucune entrée trouvée dans la configuration GRUB" "No entry found in the GRUB configuration"
def tag_live   "[sous-menu GRUB : toujours à jour]" "[GRUB submenu : always up to date]"
def tag_mem    "[memtest]" "[memtest]"
def tag_kernel "[noyau précis, obsolète après une mise à jour]" "[specific kernel, outdated after an update]"
def pv_title   "Aperçu" "Preview"
def pv_sub     "Voici le bootloader tel qu'il s'affichera au démarrage. Choisissez une entrée puis masquez la ou changez son logo. Les systèmes détectées automatiquement par OpenCore type windows ne sont pas modifiables ici" \
               "Here is the bootloader as it will appear at startup. Choose an entry then hide it or change its logo. Systems automatically detected by OpenCore like windows are not editable here"
def hint_preview "Haut/Bas, Gauche/Droite ou Tab : choisir une entrée   < / > : déplacer l'entrée|Espace : visible / masquée   L : changer le logo   D : ranger dans le sous-dossier « %s »|Entrée / clic : valider   Échap : annuler" \
                 "Up/Down, Left/Right or Tab: select an entry   < / >: move the entry|Space: show / hide   L: change the logo   D: put in the \"%s\" subfolder|Enter / click: confirm   Esc: cancel"
def pv_on      "visible" "visible"
def pv_off     "masquée" "hidden"
def pv_empty   "vide" "empty"
def pv_prev    "Aperçu OpenCore :" "OpenCore shows:"
def pv_logo    "Logo :" "Logo:"
def pv_auto    "automatique" "automatic"
def pv_pos     "Position :" "Position:"
def pv_has     "Contient :" "Contains:"
def pv_pick    "Logo de l'entrée" "Entry logo"
def pv_auto_opt "Automatique (logo de la distribution)" "Automatic (distribution logo)"
def imp_done2  "%s entrée(s) importée(s) dans le bootloader.\nRedémarrez pour tester." \
               "%s entry(ies) imported into the bootloader.\nReboot to test."
def fo_name    "Options supplémentaires" "More options"
def sp_insuf   "Espace insuffisant sur l'ESP (%s ko nécessaires)." "Not enough space on the ESP (%s KB needed)."
def hook_inst  "Installation du hook GRUB (%s) et régénération de la configuration" "Installing GRUB hook (%s) and regenerating the configuration"
def imp_done   "%s entrée(s) importée(s) dans le bootloader.\nL'entrée « %s » ouvre le menu GRUB complet.\nRedémarrez pour tester." \
               "%s entry(ies) imported into the bootloader.\nThe \"%s\" entry opens the full GRUB menu.\nReboot to test."
def cp_done    "EFI/BOOT remplacé par GRUB" "EFI/BOOT replaced by GRUB"

def st_title   "Etat" "Status"
def st_esp     "Partition EFI        : %s" "EFI partition        : %s"
def st_oc_on   "OpenCore             : installé" "OpenCore             : installed"
def st_oc_off  "OpenCore             : absent" "OpenCore             : not installed"
def st_fw      "Entrée firmware      : %s" "Firmwares entry      : %s"
def st_fw_none "absente" "missing"
def st_tools   "Entrées importées    : %s" "Imported entries    : %s"
def st_hook_on "Hook GRUB            : présent" "GRUB hook            : present"
def st_hook_off "Hook GRUB            : absent" "GRUB hook            : absent"
def st_cp_on   "Mode EFI/BOOT        : activé" "EFI/BOOT mode        : enabled"
def st_cp_off  "Mode EFI/BOOT        : inactif" "EFI/BOOT mode        : disabled"
def st_bk      "Sauvegardes          : %s" "Backups              : %s"

def un_title   "Désinstallation" "Uninstall"
def un_warn    "Ceci supprime OpenCore, les entrées importées et le hook GRUB et restaure l'état d'origine.\n\nContinuer ?" \
               "This removes OpenCore, the imported entries and the GRUB hook and restores original state.\n\nContinue?"
def un_fw      "Entrée firmware Boot%s supprimée." "Firmware entry Boot%s removed."
def un_ord_ok  "Ordre de demarrage d'origine restauré" "Original boot order restored"
def un_ord_ko  "Ordre de démarrage non restauré vérifie avec efibootmgr" "Boot order not restored check efibootmgr"
def un_hook    "Hook GRUB supprimé" "GRUB hook removed"
def un_oc      "Dossier EFI/OC supprimé" "EFI/OC folder removed"
def un_boot_ok "EFI/BOOT d'origine restauré" "Original EFI/BOOT restored"
def un_boot_rm "EFI/BOOT supprimé" "EFI/BOOT removed"
def un_manual  "Une sauvegarde manuelle /root/EFI-BOOT-backup a eté trouvée.\nL'utiliser pour restaurer EFI/BOOT ?" \
               "A manual backup /root/EFI-BOOT-backup has found.\nUse it to restore EFI/BOOT ?"
def un_delbk   "Supprimer aussi les sauvegardes (%s) ?" "Also delete the backups (%s)?"
def un_done    "Le système demarre de nouveau comme avant l'installation" "The system boots like it did before the installation"

def hint_dialog "Gauche/droite ou Tab : changer de bouton   Entrée/clic : valider   Haut/bas : défiler" \
                "Left/right or Tab: switch button   Enter/click: confirm   Up/dwn: scroll"
def quit       "Quitter" "Quit"
def dep_title  "Dépendances manquantes" "Missing dependencies"
def dep_missing "Il manque des outils nécessaires sur ce terminal :\n\n    %s\n\nPaquets à installer : %s\n\nVoulez-vous les installer maintenant ?" \
                "Some required tools are missing on this computer:\n\n    %s\n\nPackages to install: %s\n\nDo you want to install them now ?"
def dep_install "Installer maintenant" "Install now"
def dep_nopm   "Il manque des outils nécessaires sur ce terminal :\n\n    %s\n\nAucun gestionnaire de paquets reconnu, installez les manuellement puis relancez le script" \
               "Some required tools are missing on this computer:\n\n    %s\n\nNo supported package manager found install them manually then run the script again"
def dep_still  "Certaines dépendances sont toujours manquantes :\n\n    %s\n\nL'installation a échouer ou le paquet porte un autre nom sur votre distribution" \
               "Some dependencies are still missing\n\n    %s\n\nThe installation failed or the package has another name on your distribution"

def set_title  "Paramètres OpenCore" "OpenCore settings"
def set_sub    "Sélectionnez un paramètre pour le modifier, les changements sont écrits dans config.plist (backup : config.plist.bak)" \
               "Select a setting to change, changes are written in config.plist (backup: config.plist.bak)"
def s_timeout  "Délai avant démarrage automatique : %s" "Automatic boot delay: %s"
def s_show     "Afficher le sélecteur au démarrage : %s" "Show the picker at startup: %s"
def s_variant  "Thème OpenCanopy : %s" "OpenCanopy theme: %s"
def s_pointer  "Souris dans le sélecteur (beta) : %s" "Mouse in the picker (beta): %s"
def s_aux      "Afficher les entrées importées (auxiliaires) : %s" "Show imported (auxiliary) entries: %s"
def s_res      "Résolution de l'interface : %s" "Interface resolution: %s"
def s_scale    "Échelle de l'interface : %s" "Interface scale: %s"
def s_reset    "Rétablir les valeurs recommandees" "Restore recommended values"
def s_back     "Retour" "Back"
def v_on       "Activé" "On"
def v_off      "Désactivé" "Off"
def v_auto     "Automatique" "Automatic"
def v_secs     "%s s" "%s s"
def v_forever  "attendre a l'infini" "wait forever"
def s_bad      "Valeur invalide : %s" "Invalid value: %s"
def s_show_q   "Afficher le sélecteur de démarrage ?\n\n(non : OpenCore démarre directement l'entrée par défaut sans afficher de menu)" \
               "Show the boot picker ?\n\n(no: OpenCore boots the default entry directly, without showing menu)"
def s_variant_s "Choisissez le thème de l'interface OpenCanopy. Auto choisis selon le mode clair sombre." \
                "Choose the OpenCanopy interface theme. Auto follows the light/dark mode"
def s_pointer_q "Activer la souris dans le sélecteur de démarrage ?\n\n(Beta : dépend du firmware. En cas de comportement bizzare, le désactiver)" \
                "Enable mouse in the boot picker ?\n\n(Beta: depends on the firmware. If it behaves strangely, disable it)"
def s_aux_q    "Afficher les entrées importées dans le sélecteur ?\n\n(Non : elles sont masquées tant que vous n'appuyez pas sur la touche Espace.)" \
               "Show the imported entries in the picker?\n\n(No: they stay hidden until you press the Space key.)"
def s_res_s    "Choisissez la résolution de l'interface. Max utilise la résolution maximale de l'écran" \
               "Choose the interface resolution. Max uses the screen's maximum resolution"
def s_res_cust "Personnalisée…" "Custom…"
def s_res_p    "Résolution (ex. 1920x1080 ou 1920x1080@32) :" "Resolution (e.g. 1920x1080 or 1920x1080@32):"
def s_scale_s  "Choisissez l'échelle de l'interface (2x pour les écrans HiDPI / 4K)." "Choose the interface scale (2x for HiDPI / 4K screens)."
def s_reset_q  "Rétablir les valeurs recommandées ?\n\nDélai 10 s, sélecteur affiché, thème automatique, souris activée, entrées visibles, résolution Max, échelle automatique." \
               "Restore the recommended values?\n\n10 s delay, picker shown, automatic theme, mouse on, entries visible, Max resolution, automatic scale."


def un_sum_head "Voici ce qui va être supprimé :" "Here is what will be removed:"
def un_sum_fw   "  - %s entrée(s) de démarrage OpenCore dans le firmware :\n      %s" "  - %s OpenCore boot entry(ies) in the firmware:\n      %s"
def un_sum_fw0  "  - aucune entrée OpenCore dans le firmware (rien à retirer)" "  - no OpenCore entry in the firmware (nothing to remove)"
def un_sum_oc   "  - le dossier EFI/OC (%s) : OpenCore, thème, ressources et %s entrée(s) importée(s)" "  - the EFI/OC folder (%s): OpenCore, theme, resources and %s imported entry(ies)"
def un_sum_hook "  - le hook GRUB %s (la configuration GRUB sera régénérée)" "  - the GRUB hook %s (the GRUB configuration will be regenerated)"
def un_sum_nv   "  - %s variable(s) NVRAM laissée(s) par OpenCore" "  - %s NVRAM variable(s) left by OpenCore"
def un_sum_bk   "  - EFI/BOOT sera restauré à partir de la sauvegarde" "  - EFI/BOOT will be restored from the backup"
def un_sum_bkrm "  - EFI/BOOT (créé par ce script) sera supprimé" "  - EFI/BOOT (created by this script) will be removed"
def un_sum_ord  "  - l'ordre de démarrage d'origine sera rétabli : %s" "  - the original boot order will be restored: %s"
def un_sum_keep "Rien d'autre n'est impacté : vos entrées, grub et vos données restent intactes" \
                "Nothing else is affected: your entries, grub and your data remain intact"
def un_confirm  "Lancer la désinstallation complète ?" "Run the complete uninstall?"
def un_v_fw     "Plus aucune entrée OpenCore dans le firmware" "No OpenCore entry left in the firmware"
def un_v_fw_ko  "Des entrées OpenCore subsistent dans le firmware voir efibootmgr -v" "Some OpenCore entries remain in the firmware see efibootmgr -v"
def un_v_ord    "Ordre de démarrage actuel : %s" "Current boot order : %s"
def un_v_nv     "Variables NVRAM d'OpenCore supprimées" "OpenCore NVRAM variables removed"
def un_v_nv_ko  "Certaines variables NVRAM n'ont pas pu être supprimées" "Some NVRAM variables could not be removed"
def un_v_hook   "Hook GRUB supprimé et configuration GRUB régénérée" "GRUB hook removed and GRUB configuration regenerated"
def un_v_hook_ko "Le hook GRUB est encore présent dans la configuration : lancez update-grub" "The GRUB hook is still in the configuration: run update-grub"
def un_v_oc     "Dossier EFI/OC supprimé de la partition EFI" "EFI/OC folder removed from the EFI partition"
def un_v_oc_ko  "Le dossier EFI/OC n'a pas pu être supprimé" "The EFI/OC folder could not be removed"
def un_v_boot   "EFI/BOOT restauré à son état d'origine" "EFI/BOOT restored to its original state"
def un_v_bootrm "EFI/BOOT supprimé (n'existait pas avant)" "EFI/BOOT removed (was not exist before)"
def un_v_boot0  "EFI/BOOT non restauré : aucune sauvegarde n'était disponible" "EFI/BOOT not restored: no backup was available"

# iu plein ecran
write_tui() {
  cat > "$TUI" <<'PYEOF'
import argparse, curses, locale, os, sys, textwrap

os.environ.setdefault("ESCDELAY", "25")
locale.setlocale(locale.LC_ALL, "")
BTN5 = getattr(curses, "BUTTON5_PRESSED", 0x200000)


def parse():
    p = argparse.ArgumentParser()
    p.add_argument("mode"); p.add_argument("out")
    p.add_argument("--brand", default=""); p.add_argument("--title", default="")
    p.add_argument("--subtitle", default=""); p.add_argument("--hint", default="")
    p.add_argument("--ok", default="OK"); p.add_argument("--cancel", default="Cancel")
    p.add_argument("--default", type=int, default=0)
    p.add_argument("--value", default=""); p.add_argument("--textfile", default="")
    p.add_argument("--level", default="info")
    p.add_argument("--iconsfile", default=""); p.add_argument("--autologo", default="Linux")
    p.add_argument("--lab", action="append", default=[])
    argv = sys.argv[1:]
    items = []
    if "--" in argv:
        i = argv.index("--")
        argv, items = argv[:i], argv[i + 1:]
    a = p.parse_args(argv)
    a.items = items
    return a


def put(scr, y, x, s, attr=0):
    h, w = scr.getmaxyx()
    n = w - x - (1 if y == h - 1 else 0)
    if y < 0 or y >= h or x < 0 or n <= 0:
        return
    try:
        scr.addnstr(y, x, s, n, attr)
    except curses.error:
        pass


def wrap(text, width):
    out = []
    for para in text.split("\n"):
        out += textwrap.wrap(para, max(10, width), replace_whitespace=False) or [""]
    return out


def title_attr(level):
    pair = {"error": 5, "warn": 3, "ok": 6}.get(level, 3)
    return curses.color_pair(pair) | curses.A_BOLD


def draw_head(scr, a):
    h, w = scr.getmaxyx()
    scr.erase()
    bar = curses.color_pair(1) | curses.A_BOLD
    put(scr, 0, 0, " " * w, bar)
    put(scr, 0, max(0, (w - len(a.brand)) // 2), a.brand, bar)
    put(scr, 1, 2, a.title, title_attr(a.level))
    lines = wrap(a.subtitle, w - 4) if a.subtitle else []
    for i, line in enumerate(lines[:6]):
        put(scr, 2 + i, 2, line)
    return 2 + min(len(lines), 6) + 1


def footer(scr, a):
    h, w = scr.getmaxyx()
    attr = curses.color_pair(4)
    put(scr, h - 1, 0, " " * w, attr)
    put(scr, h - 1, 1, a.hint, attr)


def list_screen(scr, a, multi):
    labels, state = [], []
    for it in a.items:
        if multi:
            on, _, lab = it.partition("|")
            state.append(on == "1"); labels.append(lab)
        else:
            labels.append(it)
    n = len(labels)
    if n == 0:
        return []
    cur = min(max(a.default, 0), n - 1); top = 0
    sel_attr = curses.color_pair(2) | curses.A_BOLD

    def chosen():
        return [i for i, s in enumerate(state) if s]

    while True:
        h, w = scr.getmaxyx()
        area_top = draw_head(scr, a)
        area_h = max(1, h - 3 - area_top)
        if cur < top: top = cur
        if cur >= top + area_h: top = cur - area_h + 1
        for r in range(area_h):
            i = top + r
            if i >= n: break
            mark = ("[x] " if state[i] else "[ ] ") if multi else ""
            line = (" > " if i == cur else "   ") + mark + labels[i]
            put(scr, area_top + r, 1, line.ljust(max(0, w - 2)),
                sel_attr if i == cur else curses.A_NORMAL)
        if n > area_h:
            put(scr, 1, max(0, w - 12), "%d/%d" % (cur + 1, n))
        btn = {}
        if multi:
            okl, cl = "[ %s ]" % a.ok, "[ %s ]" % a.cancel
            y, x0 = h - 2, 3
            put(scr, y, x0, okl, sel_attr)
            put(scr, y, x0 + len(okl) + 2, cl, curses.A_BOLD)
            btn = {"ok": (y, x0, x0 + len(okl)),
                   "cancel": (y, x0 + len(okl) + 2, x0 + len(okl) + 2 + len(cl))}
        footer(scr, a)
        scr.refresh()
        try:
            k = scr.get_wch()
        except curses.error:
            continue
        if isinstance(k, str):
            if k in ("\n", "\r"):
                return chosen() if multi else [cur]
            if k == " " and multi: state[cur] = not state[cur]
            elif k in ("\x1b", "q"): return None
            elif k == "j": cur = min(n - 1, cur + 1)
            elif k == "k": cur = max(0, cur - 1)
            elif k == "a" and multi:
                v = not all(state); state = [v] * n
            elif k.isdigit() and not multi and 1 <= int(k) <= n: return [int(k) - 1]
        elif k == curses.KEY_UP: cur = max(0, cur - 1)
        elif k == curses.KEY_DOWN: cur = min(n - 1, cur + 1)
        elif k == curses.KEY_PPAGE: cur = max(0, cur - area_h)
        elif k == curses.KEY_NPAGE: cur = min(n - 1, cur + area_h)
        elif k == curses.KEY_HOME: cur = 0
        elif k == curses.KEY_END: cur = n - 1
        elif k == curses.KEY_ENTER: return chosen() if multi else [cur]
        elif k == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bs = curses.getmouse()
            except curses.error:
                continue
            if bs & curses.BUTTON4_PRESSED: cur = max(0, cur - 1)
            elif bs & BTN5: cur = min(n - 1, cur + 1)
            elif bs & (curses.BUTTON1_PRESSED | curses.BUTTON1_CLICKED):
                for name, (by, bx0, bx1) in btn.items():
                    if my == by and bx0 <= mx < bx1:
                        return chosen() if name == "ok" else None
                i = top + (my - area_top)
                if area_top <= my < area_top + area_h and 0 <= i < n:
                    cur = i
                    if multi: state[i] = not state[i]
                    else: return [i]


def input_screen(scr, a):
    val = a.value
    try: curses.curs_set(1)
    except curses.error: pass
    while True:
        h, w = scr.getmaxyx()
        area_top = draw_head(scr, a)
        put(scr, area_top + 1, 2, "> " + val, curses.A_BOLD)
        footer(scr, a)
        try: scr.move(min(h - 2, area_top + 1), min(w - 1, 4 + len(val)))
        except curses.error: pass
        scr.refresh()
        try: k = scr.get_wch()
        except curses.error: continue
        if isinstance(k, str):
            if k in ("\n", "\r"): return val
            if k == "\x1b": return None
            if k in ("\x7f", "\b"): val = val[:-1]
            elif k == "\x15": val = ""
            elif k.isprintable(): val += k
        elif k in (curses.KEY_BACKSPACE, curses.KEY_DC): val = val[:-1]
        elif k == curses.KEY_ENTER: return val


LEVEL_PAIR = {"error": 8, "warn": 9, "ok": 10, "info": 11}


def draw_box(scr, y, x, h, w, body):
    for r in range(h):
        put(scr, y + r, x, " " * w, body)
    try:
        scr.hline(y, x + 1, curses.ACS_HLINE | body, w - 2)
        scr.hline(y + h - 1, x + 1, curses.ACS_HLINE | body, w - 2)
        scr.vline(y + 1, x, curses.ACS_VLINE | body, h - 2)
        scr.vline(y + 1, x + w - 1, curses.ACS_VLINE | body, h - 2)
        scr.addch(y, x, curses.ACS_ULCORNER | body)
        scr.addch(y, x + w - 1, curses.ACS_URCORNER | body)
        scr.addch(y + h - 1, x, curses.ACS_LLCORNER | body)
        scr.addch(y + h - 1, x + w - 1, curses.ACS_LRCORNER | body)
    except curses.error:
        pass


def dialog_screen(scr, a):
    """Boîte de dialogue centrée, avec boutons. Retourne [index du bouton]."""
    text = open(a.textfile, encoding="utf-8").read() if a.textfile else ""
    buttons = a.items or ["OK"]
    focus = min(max(a.default, 0), len(buttons) - 1)
    top = 0
    body = curses.color_pair(7)
    bar = curses.color_pair(LEVEL_PAIR.get(a.level, 11)) | curses.A_BOLD
    sel_attr = curses.color_pair(2) | curses.A_BOLD
    while True:
        h, w = scr.getmaxyx()
        scr.erase()
        top_bar = curses.color_pair(1) | curses.A_BOLD
        put(scr, 0, 0, " " * w, top_bar)
        put(scr, 0, max(0, (w - len(a.brand)) // 2), a.brand, top_bar)
        btn_total = sum(len(b) + 4 for b in buttons) + 2 * (len(buttons) - 1)
        bw = max(min(w - 4, 66), min(w - 2, btn_total + 6), 20)
        lines = wrap(text, bw - 6)
        vis = max(1, min(len(lines), h - 4 - 6))
        bh = vis + 6
        y0, x0 = max(1, (h - bh) // 2), max(0, (w - bw) // 2)
        top = max(0, min(top, max(0, len(lines) - vis)))
        draw_box(scr, y0, x0, bh, bw, body)
        put(scr, y0 + 1, x0 + 1, " " * (bw - 2), bar)
        put(scr, y0 + 1, x0 + max(1, (bw - len(a.title)) // 2), a.title[:bw - 4], bar)
        for r in range(vis):
            if top + r < len(lines):
                put(scr, y0 + 3 + r, x0 + 3, lines[top + r].ljust(bw - 6), body)
        if len(lines) > vis:
            put(scr, y0 + 2, x0 + bw - 12, "(%d/%d)" % (top + 1, len(lines) - vis + 1), body)
        rects, x = [], x0 + max(1, (bw - btn_total) // 2)
        for i, b in enumerate(buttons):
            label = "[ %s ]" % b
            put(scr, y0 + bh - 2, x, label, sel_attr if i == focus else (body | curses.A_BOLD))
            rects.append((x, x + len(label)))
            x += len(label) + 2
        footer(scr, a)
        scr.refresh()
        try:
            k = scr.get_wch()
        except curses.error:
            continue
        if isinstance(k, str):
            if k in ("\n", "\r"): return [focus]
            if k == "\x1b": return None
            if k == "\t": focus = (focus + 1) % len(buttons)
            elif k == "j": top += 1
            elif k == "k": top -= 1
        elif k == curses.KEY_RIGHT: focus = min(len(buttons) - 1, focus + 1)
        elif k == curses.KEY_LEFT: focus = max(0, focus - 1)
        elif k == curses.KEY_UP: top -= 1
        elif k == curses.KEY_DOWN: top += 1
        elif k == curses.KEY_PPAGE: top -= vis
        elif k == curses.KEY_NPAGE: top += vis
        elif k == curses.KEY_ENTER: return [focus]
        elif k == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bs = curses.getmouse()
            except curses.error:
                continue
            if bs & curses.BUTTON4_PRESSED: top -= 1
            elif bs & BTN5: top += 1
            elif bs & (curses.BUTTON1_PRESSED | curses.BUTTON1_CLICKED) and my == y0 + bh - 2:
                for i, (bx0, bx1) in enumerate(rects):
                    if bx0 <= mx < bx1:
                        return [i]


TW = 16


def centered(s, n):
    return s[:n].center(n)


def popup_menu(scr, title, labels, cur):
    """Petite liste centrée par-dessus l'écran. Retourne l'index choisi ou None."""
    n = len(labels)
    body = curses.color_pair(7)
    bar = curses.color_pair(11) | curses.A_BOLD
    sel_attr = curses.color_pair(2) | curses.A_BOLD
    top = 0
    while True:
        h, w = scr.getmaxyx()
        bw = min(max(10, w - 2), max(34, len(title) + 6, max(len(l) for l in labels) + 8))
        vis = max(1, min(n, h - 6))
        bh = vis + 4
        y0, x0 = max(0, (h - bh) // 2), max(0, (w - bw) // 2)
        if cur < top: top = cur
        if cur >= top + vis: top = cur - vis + 1
        draw_box(scr, y0, x0, bh, bw, body)
        put(scr, y0 + 1, x0 + 1, " " * (bw - 2), bar)
        put(scr, y0 + 1, x0 + max(1, (bw - len(title)) // 2), title[:bw - 4], bar)
        for r in range(vis):
            i = top + r
            if i >= n: break
            line = (" > " if i == cur else "   ") + labels[i]
            put(scr, y0 + 2 + r, x0 + 1, line[:bw - 2].ljust(bw - 2), sel_attr if i == cur else body)
        if n > vis:
            put(scr, y0 + vis + 2, x0 + max(1, bw - 10), "%d/%d" % (cur + 1, n), body)
        scr.refresh()
        try:
            k = scr.get_wch()
        except curses.error:
            continue
        if isinstance(k, str):
            if k in ("\n", "\r"): return cur
            if k in ("\x1b", "q"): return None
            if k == "j": cur = min(n - 1, cur + 1)
            elif k == "k": cur = max(0, cur - 1)
        elif k == curses.KEY_UP: cur = max(0, cur - 1)
        elif k == curses.KEY_DOWN: cur = min(n - 1, cur + 1)
        elif k == curses.KEY_PPAGE: cur = max(0, cur - vis)
        elif k == curses.KEY_NPAGE: cur = min(n - 1, cur + vis)
        elif k == curses.KEY_HOME: cur = 0
        elif k == curses.KEY_END: cur = n - 1
        elif k == curses.KEY_ENTER: return cur
        elif k == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bs = curses.getmouse()
            except curses.error:
                continue
            if bs & curses.BUTTON4_PRESSED: cur = max(0, cur - 1)
            elif bs & BTN5: cur = min(n - 1, cur + 1)
            elif bs & (curses.BUTTON1_PRESSED | curses.BUTTON1_CLICKED):
                i = top + (my - (y0 + 2))
                if y0 + 2 <= my < y0 + 2 + vis and 0 <= i < n:
                    return i


def preview_screen(scr, a):
    """Aperçu du sélecteur OpenCore : ordre, visibilité, logo, sous-dossier.
    Entrée : fichier TSV (clé, nom, visible, logo, dossier, type).
    Sortie : lignes « clé<TAB>visible<TAB>logo<TAB>dossier » dans le nouvel ordre."""
    labs = dict(x.split("=", 1) for x in a.lab if "=" in x)
    L = labs.get
    items = []
    if a.textfile:
        for line in open(a.textfile, encoding="utf-8").read().splitlines():
            p = line.split("\t")
            if len(p) >= 6:
                items.append({"key": p[0], "name": p[1], "vis": p[2] == "1", "logo": p[3],
                              "fol": p[4] == "1", "kind": p[5]})
    icons = []
    if a.iconsfile and os.path.exists(a.iconsfile):
        icons = [l for l in open(a.iconsfile, encoding="utf-8").read().splitlines() if l]
    n = len(items)
    if n == 0:
        return ""
    cur, first = 0, 0
    sel_attr = curses.color_pair(2) | curses.A_BOLD
    bg = curses.color_pair(12)
    plain = ("X", "F")          # X = menu GRUB complet, F = sous-dossier

    def members():
        return [m for m in items if m["vis"] and m["fol"] and m["kind"] not in plain]

    def final_row():
        out = []
        for it in items:
            if not it["vis"]:
                continue
            if it["kind"] == "F":
                if members():
                    out.append(it["name"])
            elif it["fol"]:
                continue
            else:
                out.append(it["name"])
        return out

    def result():
        return "\n".join("\t".join([e["key"], "1" if e["vis"] else "0", e["logo"],
                                    "1" if e["fol"] else "0"]) for e in items)

    while True:
        h, w = scr.getmaxyx()
        top = draw_head(scr, a)
        per = max(1, (w - 4) // TW)
        if cur < first: first = cur
        if cur >= first + per: first = cur - per + 1
        first = max(0, min(first, max(0, n - per)))
        box_h, box_w = 8, min(max(10, w - 2), per * TW + 2)
        bx = max(0, (w - box_w) // 2)
        draw_box(scr, top, bx, box_h, box_w, bg)
        put(scr, top, bx + 2, " OpenCore ", bg | curses.A_BOLD)
        put(scr, top, max(0, bx + box_w - 10), " %d/%d " % (cur + 1, n), bg)
        nm = len(members())
        for idx in range(first, min(n, first + per)):
            it = items[idx]
            tx, ty = bx + 2 + (idx - first) * TW, top + 1
            if it["kind"] == "F" and nm == 0:
                status = "(%s)" % L("empty", "empty")
            elif it["vis"]:
                status = "[x] " + L("on", "visible")
            else:
                status = "[ ] " + L("off", "hidden")
            label = ("> " if (it["fol"] and it["kind"] not in plain) else "") + it["name"]
            logo = it["logo"] or "(%s)" % a.autologo
            rows = ["+" + "-" * 12 + "+",
                    "|" + centered("[ %s ]" % (it["name"][:1] or "?").upper(), 12) + "|",
                    "|" + centered(logo, 12) + "|",
                    "+" + "-" * 12 + "+",
                    centered(label, 14),
                    centered(status, 14)]
            if idx == cur:
                attr = sel_attr if it["vis"] else curses.color_pair(13) | curses.A_BOLD
            else:
                attr = bg if it["vis"] else bg | curses.A_DIM
            for r, txt in enumerate(rows):
                put(scr, ty + r, tx, txt, attr)
        if first > 0:
            put(scr, top + 3, bx + 1, "<", bg | curses.A_BOLD)
        if first + per < n:
            put(scr, top + 3, bx + box_w - 2, ">", bg | curses.A_BOLD)

        y = top + box_h
        pl = wrap("%s %s" % (L("prev", "OpenCore:"), "   ".join(final_row()) or "-"), w - 4)
        for i, line in enumerate(pl[:2]):
            put(scr, y + i, 2, line, curses.A_BOLD)
        y += min(len(pl), 2)
        it = items[cur]
        tag = {"S": L("kS", ""), "C": L("kC", ""), "M": L("kM", "")}.get(it["kind"], "")
        put(scr, y, 2, ("%s  %s" % (it["name"], tag)).strip(), curses.color_pair(3) | curses.A_BOLD)
        logo_t = it["logo"] or "%s (%s)" % (L("auto", "auto"), a.autologo)
        put(scr, y + 1, 2, "%s %s     %s %d/%d" % (L("logo", "Logo:"), logo_t, L("pos", "Position:"), cur + 1, n))
        if it["kind"] == "F":
            put(scr, y + 2, 2, "%s %s" % (L("has", "Contains:"), ", ".join(m["name"] for m in members()) or "-"))

        okl, cl = "[ %s ]" % a.ok, "[ %s ]" % a.cancel
        brow, bx0 = h - 2, 3
        put(scr, brow, bx0, okl, sel_attr)
        put(scr, brow, bx0 + len(okl) + 2, cl, curses.A_BOLD)
        btn = {"ok": (brow, bx0, bx0 + len(okl)),
               "cancel": (brow, bx0 + len(okl) + 2, bx0 + len(okl) + 2 + len(cl))}
        parts = a.hint.split("|")
        extra = parts[:-1]
        for i, pt in enumerate(extra):
            put(scr, h - 3 - (len(extra) - 1 - i), 2, pt, curses.A_DIM)
        fattr = curses.color_pair(4)
        put(scr, h - 1, 0, " " * w, fattr)
        put(scr, h - 1, 1, parts[-1], fattr)
        scr.refresh()

        try:
            k = scr.get_wch()
        except curses.error:
            continue
        if isinstance(k, str):
            if k in ("\n", "\r"): return result()
            if k in ("\x1b", "q"): return None
            if k == "\t": cur = (cur + 1) % n
            elif k == " ": it["vis"] = not it["vis"]
            elif k in ("d", "D"):
                if it["kind"] not in plain:
                    it["fol"] = not it["fol"]
            elif k in ("<", ","):
                if cur > 0:
                    items[cur - 1], items[cur] = items[cur], items[cur - 1]
                    cur -= 1
            elif k in (">", "."):
                if cur < n - 1:
                    items[cur + 1], items[cur] = items[cur], items[cur + 1]
                    cur += 1
            elif k in ("l", "L"):
                labels = [L("auto_opt", "Automatic")] + icons
                start = icons.index(it["logo"]) + 1 if it["logo"] in icons else 0
                r = popup_menu(scr, "%s : %s" % (L("pick", "Logo"), it["name"]), labels, start)
                if r is not None:
                    it["logo"] = "" if r == 0 else icons[r - 1]
            elif k == "j": cur = min(n - 1, cur + 1)
            elif k == "k": cur = max(0, cur - 1)
        elif k == curses.KEY_LEFT: cur = max(0, cur - 1)
        elif k == curses.KEY_RIGHT: cur = min(n - 1, cur + 1)
        elif k == curses.KEY_UP: cur = max(0, cur - 1)
        elif k == curses.KEY_DOWN: cur = min(n - 1, cur + 1)
        elif k == curses.KEY_BTAB: cur = (cur - 1) % n
        elif k == curses.KEY_HOME: cur = 0
        elif k == curses.KEY_END: cur = n - 1
        elif k == curses.KEY_ENTER: return result()
        elif k == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bs = curses.getmouse()
            except curses.error:
                continue
            if bs & curses.BUTTON4_PRESSED: cur = max(0, cur - 1)
            elif bs & BTN5: cur = min(n - 1, cur + 1)
            elif bs & (curses.BUTTON1_PRESSED | curses.BUTTON1_CLICKED):
                for name, (by_, bx_0, bx_1) in btn.items():
                    if my == by_ and bx_0 <= mx < bx_1:
                        return result() if name == "ok" else None
                col = (mx - (bx + 2)) // TW
                if top < my < top + box_h - 1 and 0 <= col < per and first + col < n:
                    cur = first + col


def main():
    a = parse()

    def run(scr):
        try: curses.curs_set(0)
        except curses.error: pass
        try:
            curses.start_color()
            bg = curses.COLOR_BLACK
            try:
                curses.use_default_colors(); bg = -1
            except curses.error:
                pass
            curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLUE)
            curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_CYAN)
            curses.init_pair(3, curses.COLOR_YELLOW, bg)
            curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_WHITE)
            curses.init_pair(5, curses.COLOR_RED, bg)
            curses.init_pair(6, curses.COLOR_GREEN, bg)
            curses.init_pair(7, curses.COLOR_BLACK, curses.COLOR_WHITE)    # corps des dialogues
            curses.init_pair(8, curses.COLOR_WHITE, curses.COLOR_RED)      # dialogue : erreur
            curses.init_pair(9, curses.COLOR_BLACK, curses.COLOR_YELLOW)   # dialogue : attention
            curses.init_pair(10, curses.COLOR_WHITE, curses.COLOR_GREEN)   # dialogue : succès
            curses.init_pair(11, curses.COLOR_WHITE, curses.COLOR_BLUE)    # dialogue : information
            curses.init_pair(12, curses.COLOR_WHITE, curses.COLOR_BLACK)   # aperçu : écran de démarrage
            curses.init_pair(13, curses.COLOR_BLACK, curses.COLOR_WHITE)
        except curses.error:
            pass
        try:
            curses.mousemask(curses.ALL_MOUSE_EVENTS); curses.mouseinterval(0)
        except curses.error:
            pass
        scr.keypad(True)
        if a.mode == "menu": return list_screen(scr, a, False)
        if a.mode == "check": return list_screen(scr, a, True)
        if a.mode == "input": return input_screen(scr, a)
        if a.mode == "preview": return preview_screen(scr, a)
        return dialog_screen(scr, a)

    try:
        res = curses.wrapper(run)
    except KeyboardInterrupt:
        sys.exit(130)
    if res is None:
        sys.exit(1)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(res if isinstance(res, str) else " ".join(str(i) for i in res))


main()
PYEOF
}

# enveloppes bash autour de l'interface
ui_run() {
  local mode=$1 title=$2 sub=$3 hint=$4; shift 4
  rm -f "$WORK/ui.out"
  python3 "$TUI" "$mode" "$WORK/ui.out" --brand "$BRAND" --title "$title" --subtitle "$sub" \
    --hint "$hint" --ok "$(t btn_ok)" --cancel "$(t btn_cancel)" "$@"
  local rc=$?
  UI_RESULT=$(cat "$WORK/ui.out" 2>/dev/null || true)
  return $rc
}
ui_menu()  { local ti=$1 su=$2 de=$3; shift 3; ui_run menu  "$ti" "$su" "$(t hint_menu)"  --default "$de" -- "$@"; }
ui_check() { local ti=$1 su=$2; shift 2;        ui_run check "$ti" "$su" "$(t hint_check)" -- "$@"; }
ui_input() { ui_run input "$1" "$2" "$(t hint_input)" --value "${3:-}"; }
ui_alert() {
  local ti=$1 tx=$2 lv=$3; shift 3
  printf '%s' "$tx" > "$WORK/msg.txt"
  ui_run dialog "$ti" "" "$(t hint_dialog)" --textfile "$WORK/msg.txt" --level "$lv" \
    --default "${UI_DEFAULT:-0}" -- "$@"
}
ui_msg()   { ui_alert "$1" "$2" "${3:-info}" "$(t btn_ok)" || true; }
ui_yesno() {
  UI_DEFAULT=${3:-0} ui_alert "$1" "$2" "${4:-info}" "$(t yes)" "$(t no)" || return 1
  [ "$UI_RESULT" = 0 ]
}

plain_begin() { clear; printf '%s%s%s\n\n' "$C_B" "$BRAND" "$C_0"; }
info() { echo "${C_G}==>${C_0} $*"; }
warn() { echo "${C_Y}[!]${C_0} $*"; }
die()  { ui_msg "$(t err_title)" "$*" error; exit 1; }

# etat
load_state() { if [ -f "$STATE_FILE" ]; then source "$STATE_FILE"; fi; }
save_state() {
  [ "$NO_SAVE" = 1 ] && return 0
  [ "$EUID" -eq 0 ] || return 0
  mkdir -p "$STATE_DIR"
  local v
  for v in LANG_UI ESP BOOT_EXISTED ORIG_BOOTORDER OC_BOOTNUM COMPAT GRUBDIR; do
    printf '%s=%q\n' "$v" "${!v}"
  done > "$STATE_FILE"
}

#verifs
find_esp() {
  if [ -n "$ESP" ] && mountpoint -q "$ESP"; then return 0; fi
  local d
  for d in /boot/efi /efi /boot; do
    if mountpoint -q "$d" && [ "$(findmnt -no FSTYPE "$d")" = vfat ]; then ESP=$d; return 0; fi
  done
  ui_input "$(t esp_title)" "$(t esp_prompt)" "" || exit 0
  ESP=$UI_RESULT
  mountpoint -q "$ESP" || die "$(t esp_nomount "$ESP")"
}

check_secureboot() {
  local f=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c v
  if [ -r "$f" ]; then
    v=$(od -An -t u1 -j4 -N1 "$f" | tr -d ' ')
    if [ "$v" = 1 ]; then ui_yesno "$(t warn_title)" "$(t sb_warn)" 1 warn || return 1; fi
  fi
  return 0
}

DEP_CMDS=(curl unzip efibootmgr python3 lsblk findmnt mountpoint tar)
MISSING=()

detect_pm() {
  local pm
  for pm in apt-get dnf pacman zypper xbps-install; do
    if command -v "$pm" >/dev/null; then echo "$pm"; return 0; fi
  done
  return 0
}

dep_pkg() {
  case $1 in
    lsblk|findmnt|mountpoint) echo util-linux ;;
    python3) if [ "$(detect_pm)" = pacman ]; then echo python; else echo python3; fi ;;
    *) echo "$1" ;;
  esac
}

missing_deps() {
  MISSING=(); local c
  for c in "${DEP_CMDS[@]}"; do command -v "$c" >/dev/null || MISSING+=("$c"); done
}

pm_install() {
  case $(detect_pm) in
    apt-get)      apt-get update -qq; apt-get install -y "$@" ;;
    dnf)          dnf install -y "$@" ;;
    pacman)       pacman -S --needed --noconfirm "$@" ;;
    zypper)       zypper --non-interactive install "$@" ;;
    xbps-install) xbps-install -Sy "$@" ;;
    *)            return 1 ;;
  esac
}

check_deps() {
  missing_deps
  [ ${#MISSING[@]} -eq 0 ] && return 0
  local pkgs=() c p list pm
  for c in "${MISSING[@]}"; do
    p=$(dep_pkg "$c")
    [[ " ${pkgs[*]-} " == *" $p "* ]] || pkgs+=("$p")
  done
  list=$(IFS=,; echo "${MISSING[*]}"); list=${list//,/, }
  pm=$(detect_pm)
  if [ -z "$pm" ]; then ui_msg "$(t dep_title)" "$(t dep_nopm "$list")" error; return 1; fi
  UI_DEFAULT=0 ui_alert "$(t dep_title)" "$(t dep_missing "$list" "${pkgs[*]}")" warn \
    "$(t dep_install)" "$(t quit)" || return 1
  [ "$UI_RESULT" = 0 ] || return 1
  plain_begin
  pm_install "${pkgs[@]}" || true
  missing_deps
  if [ ${#MISSING[@]} -gt 0 ]; then
    ui_msg "$(t dep_title)" "$(t dep_still "${MISSING[*]}")" error
    return 1
  fi
  return 0
}

# Python3
ensure_python() {
  if command -v python3 >/dev/null && python3 -c 'import curses' 2>/dev/null; then return 0; fi
  echo "${C_B}$BRAND${C_0}"; echo
  echo "Python 3 (module curses) est requis pour afficher l'interface."
  echo "Python 3 (curses module) is required to display the interface."
  if [ "$EUID" -ne 0 ]; then echo; echo "    sudo bash $0"; exit 1; fi
  local r pk=(python3)
  if command -v pacman >/dev/null; then pk=(python); fi
  if command -v zypper >/dev/null; then pk=(python3 python3-curses); fi
  read -rp "Installer maintenant / Install now ? [o/y/N] " r
  [[ $r =~ ^[oOyY]$ ]] || exit 1
  pm_install "${pk[@]}" || exit 1
  python3 -c 'import curses' 2>/dev/null || { echo "python3 curses: KO"; exit 1; }
}

# sauvegarde
backup_esp() {
  mkdir -p "$BACKUP_DIR"
  [ -n "$ORIG_BOOTORDER" ] || ORIG_BOOTORDER=$(efibootmgr | awk '/^BootOrder/{print $2}')
  if [ -f "$BACKUP_DIR/.done" ]; then return 0; fi

  local src="" guess=""
  if [ -d "$ESP/EFI/OC" ]; then
    [ -d /root/EFI-BOOT-backup ] && guess=/root/EFI-BOOT-backup
    ui_input "$(t old_title)" "$(t old_prompt)" "$guess" || return 1
    src=$UI_RESULT
    if [ -n "$src" ] && [ ! -d "$src" ]; then die "$(t dir_nf "$src")"; fi
  fi
  [ -n "$src" ] || src="$ESP/EFI/BOOT"
  if [ -d "$src" ]; then
    rm -rf "$BACKUP_DIR/EFI-BOOT"
    cp -a "$src" "$BACKUP_DIR/EFI-BOOT" || die "$(t bk_fail)"
    BOOT_EXISTED=1
  else
    BOOT_EXISTED=0
  fi
  tar -C "$ESP" -cf "$BACKUP_DIR/EFI-complet-$(date +%F-%H%M).tar" EFI
  touch "$BACKUP_DIR/.done"
  save_state
  info "$(t bk_done "$BACKUP_DIR")"
}

#OpenCore
write_config() {
  SAMPLE="$WORK/oc/Docs/Sample.plist" OUT="$ESP/EFI/OC/config.plist" TIMEOUT="$1" python3 - <<'PY'
import plistlib, os
c = plistlib.load(open(os.environ["SAMPLE"], "rb"))

# Rien de spécifique à macOS
c["ACPI"].update(Add=[], Delete=[], Patch=[])
c["Booter"].update(MmioWhitelist=[], Patch=[])
for k, v in list(c["Booter"]["Quirks"].items()):
    if isinstance(v, bool):
        c["Booter"]["Quirks"][k] = False          # ne pas toucher à la mémoire UEFI
c["Kernel"].update(Add=[], Block=[], Force=[], Patch=[])
c["DeviceProperties"]["Add"] = {}

# Uniquement l'interface graphique (OpenRuntime inutile hors macOS)
c["UEFI"]["Drivers"] = [{"Path": "OpenCanopy.efi", "Enabled": True, "Arguments": "", "Comment": ""}]
for k in ("ProtectUefiServices", "ReleaseUsbOwnership"):
    if k in c["UEFI"]["Quirks"]:
        c["UEFI"]["Quirks"][k] = False

c["Misc"]["Boot"].update(PickerMode="External", PickerAttributes=17, ShowPicker=True,
                         Timeout=int(os.environ["TIMEOUT"]), HideAuxiliary=False)
c["Misc"]["Security"].update(ScanPolicy=0, SecureBootModel="Disabled", Vault="Optional")
c["Misc"]["Tools"] = []
c["Misc"]["Entries"] = []

# Ne rien écrire dans la NVRAM du firmware (variables Apple inutiles sous Linux)
nv = c.setdefault("NVRAM", {})
nv.update(Add={}, Delete={}, LegacyOverwrite=False, WriteFlash=False)
if "LegacySchema" in nv:
    nv["LegacySchema"] = {}
plistlib.dump(c, open(os.environ["OUT"], "wb"))
PY
}

install_opencore() {
  local ver oc="$ESP/EFI/OC" free_kb regen=0
  free_kb=$(df -Pk "$ESP" | awk 'NR==2{print $4}')
  [ "$free_kb" -gt 30000 ] || die "$(t space_low)"

  if [ -f "$oc/config.plist" ]; then
    if ui_yesno "$(t old_title)" "$(t cfg_exists)" 1; then regen=1; fi
  else
    regen=1
  fi
  local timeout=10
  if [ "$regen" = 1 ]; then
    ui_input "$(t to_title)" "$(t to_prompt)" 10 || exit 0
    timeout=${UI_RESULT:-10}; [[ $timeout =~ ^[0-9]+$ ]] || timeout=10
  fi

  plain_begin
  info "$(t gh_search)"
  ver=$(curl -fsSL https://api.github.com/repos/acidanthera/OpenCorePkg/releases/latest \
        | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])') || die "$(t gh_fail)"
  info "$(t oc_ver "$ver")"
  curl -fsSL -o "$WORK/oc.zip"  "https://github.com/acidanthera/OpenCorePkg/releases/download/${ver}/OpenCore-${ver}-RELEASE.zip" || die "$(t dl_oc_fail)"
  curl -fsSL -o "$WORK/bin.zip" "https://github.com/acidanthera/OcBinaryData/archive/refs/heads/master.zip" || die "$(t dl_res_fail)"
  unzip -q "$WORK/oc.zip"  -d "$WORK/oc"
  unzip -q "$WORK/bin.zip" -d "$WORK/bin"

  mkdir -p "$oc/Drivers" "$oc/Tools" "$oc/Resources"
  cp "$WORK/oc/X64/EFI/OC/OpenCore.efi" "$oc/"                    || die "$(t cp_fail OpenCore.efi)"
  cp "$WORK/oc/X64/EFI/OC/Drivers/OpenCanopy.efi" "$oc/Drivers/"  || die "$(t cp_fail OpenCanopy.efi)"
  rm -f "$oc/Drivers/OpenRuntime.efi"
  cp -r "$WORK"/bin/OcBinaryData-*/Resources/{Font,Image,Label} "$oc/Resources/" || die "$(t cp_fail Resources)"

  if [ "$regen" = 1 ]; then
    [ -f "$oc/config.plist" ] && cp "$oc/config.plist" "$oc/config.plist.bak"
    write_config "$timeout"
  fi
}

fw_oc_entries() {
  efibootmgr -v 2>/dev/null | BRAND="$BRAND" python3 -c '
import os, re, sys
for line in sys.stdin:
    m = re.match(r"^Boot([0-9A-Fa-f]{4})\*?\s+(.*)$", line.rstrip("\n"))
    if not m:
        continue
    num, rest = m.groups()
    label = rest.split("\t")[0].strip()
    if re.search(r"\\EFI\\OC\\OPENCORE\.EFI", rest, re.I) or label.startswith("OpenCore") or label == os.environ["BRAND"]:
        print(num + "\t" + label)
'
}
fw_nums() { fw_oc_entries | cut -f1; }
fw_set_first() {
  local order
  order=$(efibootmgr | awk '/^BootOrder/{print $2}' | tr ',' '\n' | grep -vix "$1" | paste -sd, - || true)
  efibootmgr -o "$1${order:+,$order}" >/dev/null
}

create_boot_entry() {
  local old first wasfirst=0 src disk part
  OC_BOOTNUM=$(efibootmgr | grep -F "$BRAND" | sed -nE 's/^Boot([0-9A-Fa-f]{4}).*/\1/p' | head -1)
  if [ -z "$OC_BOOTNUM" ]; then
    first=$(efibootmgr | awk '/^BootOrder/{print $2}' | cut -d, -f1)
    for old in $(fw_nums); do
      [ "$old" = "$first" ] && wasfirst=1
      efibootmgr -b "$old" -B >/dev/null
      info "$(t fw_renamed "$old")"
    done
    src=$(findmnt -no SOURCE "$ESP")
    disk="/dev/$(lsblk -no PKNAME "$src" | head -1)"
    part=$(cat "/sys/class/block/$(basename "$src")/partition")
    efibootmgr --create --disk "$disk" --part "$part" --label "$BRAND" \
      --loader '\EFI\OC\OpenCore.efi' >/dev/null || die "$(t fw_fail)"
    OC_BOOTNUM=$(efibootmgr | grep -F "$BRAND" | sed -nE 's/^Boot([0-9A-Fa-f]{4}).*/\1/p' | head -1)
    if [ "$wasfirst" = 1 ] || ui_yesno "$(t fw_first_t)" "$(t fw_first_q "$BRAND")" 0; then
      fw_set_first "$OC_BOOTNUM" || true
    fi
  fi
  save_state
}

# GRUB
find_grub_dir() {
  if [ -n "$GRUBDIR" ] && [ -f "$GRUBDIR/grubx64.efi" ]; then return 0; fi
  local cands=() f d n
  shopt -s nullglob nocaseglob
  for f in "$ESP"/EFI/*/grubx64.efi; do
    d=$(dirname "$f"); n=${d##*/}
    if [[ ${n,,} == boot || ${n,,} == oc ]]; then continue; fi
    cands+=("$d")
  done
  shopt -u nullglob nocaseglob
  case ${#cands[@]} in
    0) return 1 ;;
    1) GRUBDIR=${cands[0]} ;;
    *) ui_menu "$(t multi_t)" "$(t multi_s)" 0 "${cands[@]}" || return 1
       GRUBDIR=${cands[$UI_RESULT]} ;;
  esac
  save_state
}

find_grub_cfg() {
  local f
  for f in /boot/grub/grub.cfg /boot/grub2/grub.cfg; do
    if [ -f "$f" ] && grep -q '^[[:space:]]*menuentry ' "$f"; then GRUB_CFG=$f; return 0; fi
  done
  return 1
}

regen_grub() {
  if   command -v update-grub >/dev/null;    then update-grub
  elif command -v grub-mkconfig >/dev/null;  then grub-mkconfig -o "${GRUB_CFG:-/boot/grub/grub.cfg}"
  elif command -v grub2-mkconfig >/dev/null; then grub2-mkconfig -o "${GRUB_CFG:-/boot/grub2/grub.cfg}"
  else warn "grub-mkconfig ?"; fi
}

install_hook() {
  cat > "$HOOK" <<'EOF'
#!/bin/sh
cat <<'GRUBEOF'
# OpenCore Bootlinuxer by BecabDev : l'entrée choisie dans OpenCore prime sur le choix par défaut
if [ -n "${oc_default}" ]; then
  set default="${oc_default}"
  if [ -n "${oc_wait}" ]; then
    set timeout=-1
    set timeout_style=menu
  else
    set timeout=0
    set timeout_style=hidden
  fi
fi
GRUBEOF
EOF
  chmod 755 "$HOOK"
  regen_grub
}

parse_entries() {
  GRUB_CFG="$GRUB_CFG" python3 - > "$WORK/entries.tsv" <<'PY'
import os, re
lines = open(os.environ["GRUB_CFG"], errors="replace").read().splitlines()
pat   = re.compile(r"""^\s*(menuentry|submenu)\s+(?:'([^']*)'|"([^"]*)")(.*)$""")
idpat = re.compile(r"""(?:--id\s+|\$menuentry_id_option\s+)(?:'([^']*)'|"([^"]*)"|(\S+))""")
mem   = re.compile(r"memtest|memory test", re.I)
depth, parent = 0, None
for line in lines:
    m = pat.match(line)
    if m:
        kind  = m.group(1)
        title = m.group(2) if m.group(2) is not None else m.group(3)
        im    = idpat.search(m.group(4))
        ident = next((g for g in im.groups() if g), None) if im else None
        sel   = ident or title
        if kind == "submenu" and depth == 0:
            parent = sel
            print("\t".join(["S", title, sel]))
        elif kind == "menuentry":
            if parent is not None and depth >= 1:
                print("\t".join(["C", title, parent + ">" + sel]))
            elif depth == 0:
                print("\t".join(["M" if mem.search(title) else "E", title, sel]))
    depth += line.count("{") - line.count("}")
    if depth <= 0:
        depth, parent = 0, None
PY
}

gesc() { local s=$1; s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//\$/\\\$}; printf '%s' "$s"; }

make_tool_dir() {
  local d="$ESP/EFI/OC/Tools/$1"
  mkdir -p "$d" || return 1
  cp "$GRUBDIR/grubx64.efi" "$d/grubx64.efi" || return 1
  if [ -f "$GRUBDIR/grub.cfg" ]; then
    if [ -n "${2:-}" ]; then
      {
        printf 'set oc_default="%s"\n' "$(gesc "$2")"
        if [ "${3:-0}" = 1 ]; then printf 'set oc_wait=1\nexport oc_wait\n'; fi
        printf 'export oc_default\n'
        cat "$GRUBDIR/grub.cfg"
      } > "$d/grub.cfg"
    else
      cp "$GRUBDIR/grub.cfg" "$d/grub.cfg"
    fi
  fi
}

make_folder_dir() {
  local d="$ESP/EFI/OC/Tools/ocm-folder" nm sel wt
  mkdir -p "$d" || return 1
  cp "$GRUBDIR/grubx64.efi" "$d/grubx64.efi" || return 1
  {
    grep -vi configfile "$GRUBDIR/grub.cfg"
    echo 'set timeout=-1'
    echo 'set default=0'
    while IFS=$'\t' read -r nm sel wt; do
      printf 'menuentry "%s" {\n  set oc_default="%s"\n  export oc_default\n' "$(gesc "$nm")" "$(gesc "$sel")"
      if [ "$wt" = 1 ]; then printf '  set oc_wait=1\n  export oc_wait\n'; fi
      printf '  configfile $prefix/grub.cfg\n}\n'
    done < "$1"
  } > "$d/grub.cfg"
}

main_entry_name() {
  local n
  n=$(. /etc/os-release 2>/dev/null; echo "${NAME:-${ID:-Linux}}")
  printf '%s' "${n:-Linux}"
}

build_layout() {
  MAIN="$(main_entry_name)" FOLDER="$(t fo_name)" STUB="$1" ENTRIES="$WORK/entries.tsv" \
  SAVED="$STATE_DIR/layout.tsv" OLDMAP="$STATE_DIR/icons.map" python3 - > "$WORK/layout.in" <<'PY'
import os, re
E = os.environ
risky = re.compile(r"Windows|UEFI|[Ff]irmware|[Ss]etup")
saved, order = {}, []
if os.path.exists(E["SAVED"]):
    for l in open(E["SAVED"], encoding="utf-8"):
        p = l.rstrip("\n").split("\t")
        if len(p) >= 4 and p[0] not in saved:
            saved[p[0]] = (p[1] == "1", p[2], p[3] == "1")
            order.append(p[0])
oldicons = {}
if os.path.exists(E["OLDMAP"]):           # ancien format (logos par nom d'entrée)
    for l in open(E["OLDMAP"], encoding="utf-8"):
        if "\t" in l:
            k, v = l.rstrip("\n").split("\t", 1)
            oldicons[k] = v
items = {"main": (E["MAIN"], "X", True, "", False)}
natural = ["main"]
if E["STUB"] == "1":
    for l in open(E["ENTRIES"], encoding="utf-8"):
        p = l.rstrip("\n").split("\t")
        if len(p) < 3:
            continue
        kind, title, sel = p[0], p[1], p[2]
        if sel in items or sel in ("main", "folder"):
            continue
        vis = not (kind == "C" or (kind == "E" and risky.search(title)))
        items[sel] = (title, kind, vis, oldicons.get(title, ""), kind in ("C", "S", "M"))
        natural.append(sel)
    if len(natural) > 1:
        items["folder"] = (E["FOLDER"], "F", True, "", False)
        natural.append("folder")
seq = [k for k in order if k in items] + [k for k in natural if k not in order]
for key in seq:
    title, kind, vis, logo, fol = items[key]
    if key in saved:
        vis, logo, fol = saved[key]
    if kind in ("X", "F"):
        fol = False
    print("\t".join([key, title, "1" if vis else "0", logo, "1" if fol else "0", kind]))
PY
}

plan_layout() {
  IN="$WORK/layout.in" OUT="$WORK/layout.out" PLAN="$WORK/plan.tsv" MEM="$WORK/members.tsv" python3 - <<'PY'
import os
E = os.environ
info = {}
for l in open(E["IN"], encoding="utf-8"):
    p = l.rstrip("\n").split("\t")
    if len(p) >= 6:
        info[p[0]] = (p[1], p[5])
seq = []
for l in open(E["OUT"], encoding="utf-8"):
    p = l.rstrip("\n").split("\t")
    if len(p) >= 4 and p[0] in info:
        name, kind = info[p[0]]
        seq.append({"key": p[0], "name": name, "kind": kind, "vis": p[1] == "1",
                    "logo": p[2] or "-", "fol": p[3] == "1" and kind not in ("X", "F")})
members = [i for i in seq if i["vis"] and i["fol"]]
plan, n = [], 0
for i in seq:
    if not i["vis"]:
        continue
    if i["kind"] == "X":
        plan.append(("main", "ocm-main", i["name"], "-", "0", i["logo"]))
    elif i["kind"] == "F":
        if members:
            plan.append(("folder", "ocm-folder", i["name"], "-", "0", i["logo"]))
    elif i["fol"]:
        continue
    else:
        n += 1
        plan.append(("entry", "ocm-%d" % n, i["name"], i["key"], "1" if i["kind"] == "S" else "0", i["logo"]))
open(E["PLAN"], "w", encoding="utf-8").write("".join("\t".join(r) + "\n" for r in plan))
open(E["MEM"], "w", encoding="utf-8").write(
    "".join("%s\t%s\t%s\n" % (m["name"], m["key"], "1" if m["kind"] == "S" else "0") for m in members))
PY
}

ui_preview() {
  local flav; flav=$(distro_flavour); flav=${flav%%:*}
  ui_run preview "$(t pv_title)" "$(t pv_sub)" "$(t hint_preview "$(t fo_name)")" \
    --textfile "$WORK/layout.in" --iconsfile "$WORK/icons.lst" --autologo "$flav" \
    --lab "on=$(t pv_on)" --lab "off=$(t pv_off)" --lab "empty=$(t pv_empty)" \
    --lab "prev=$(t pv_prev)" --lab "logo=$(t pv_logo)" --lab "auto=$(t pv_auto)" \
    --lab "pos=$(t pv_pos)" --lab "has=$(t pv_has)" --lab "pick=$(t pv_pick)" \
    --lab "auto_opt=$(t pv_auto_opt)" --lab "kS=$(t tag_live)" --lab "kC=$(t tag_kernel)" \
    --lab "kM=$(t tag_mem)"
}

do_import() {
  [ -f "$ESP/EFI/OC/config.plist" ] || { ui_msg "$(t err_title)" "$(t no_oc)" error; return 1; }
  find_grub_dir || { ui_msg "$(t err_title)" "$(t no_grub)" error; return 1; }
  find_grub_cfg || { ui_msg "$(t err_title)" "$(t no_cfg)" error; return 1; }

  local stub=1 notes=""
  if [ ! -f "$GRUBDIR/grub.cfg" ]; then stub=0; notes+="$(t no_stub "$GRUBDIR")"$'\n\n'; fi
  if grep -q blscfg "$GRUB_CFG"; then notes+="$(t bls_warn)"$'\n\n'; fi
  [ -n "$notes" ] && ui_msg "$(t warn_title)" "$notes" warn

  : > "$WORK/entries.tsv"
  if [ "$stub" = 1 ]; then
    parse_entries
    [ -s "$WORK/entries.tsv" ] || ui_msg "$(t warn_title)" "$(t no_entries)" warn
  fi

  mkdir -p "$STATE_DIR"
  build_layout "$stub"
  list_icons > "$WORK/icons.lst"
  ui_preview || return 0
  printf '%s\n' "$UI_RESULT" > "$WORK/layout.out"
  cp "$WORK/layout.out" "$STATE_DIR/layout.tsv"
  plan_layout

  local total sz free_kb need_kb
  total=$(wc -l < "$WORK/plan.tsv")
  sz=$(stat -c %s "$GRUBDIR/grubx64.efi")
  need_kb=$(( total * sz / 1024 + 2048 ))
  free_kb=$(df -Pk "$ESP" | awk 'NR==2{print $4}')
  [ "$free_kb" -gt "$need_kb" ] || { ui_msg "$(t err_title)" "$(t sp_insuf "$need_kb")" error; return 1; }

  plain_begin
  rm -rf "$ESP"/EFI/OC/Tools/ocm-*
  mkdir -p "$ESP/EFI/OC/Tools"
  : > "$WORK/tools.tsv"

  local type dir name sel wait logo nsel=0
  while IFS=$'\t' read -r type dir name sel wait logo; do
    case $type in
      main)   make_tool_dir "$dir" "" 0 || die "$(t cp_fail "$dir")" ;;
      entry)  make_tool_dir "$dir" "$sel" "$wait" || die "$(t cp_fail "$name")"; nsel=$((nsel+1)) ;;
      folder) make_folder_dir "$WORK/members.tsv" || die "$(t cp_fail "$dir")"; nsel=$((nsel+1)) ;;
    esac
    printf '%s\t%s\t%s\n' "$name" "$dir\\grubx64.efi" "$logo" >> "$WORK/tools.tsv"
  done < "$WORK/plan.tsv"

  local flav
  flav=$(. /etc/os-release 2>/dev/null; echo "${ID:-linux}"); flav="${flav^}:Linux"
  CFG="$ESP/EFI/OC/config.plist" TSV="$WORK/tools.tsv" FLAVOUR="$flav" python3 - <<'PY'
import plistlib, os, unicodedata
f = os.environ["CFG"]
c = plistlib.load(open(f, "rb"))
tools = [t for t in c["Misc"].get("Tools", []) if t.get("Comment") != "ocm"]
for line in open(os.environ["TSV"], encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    name, path = parts[0], parts[1]
    logo = parts[2] if len(parts) > 2 and parts[2] != "-" else ""
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()[:48] or "Linux"
    flavour = (logo + ":" if logo else "") + os.environ["FLAVOUR"]
    tools.append({"Name": name, "Path": path, "Arguments": "", "Comment": "ocm",
                  "Enabled": True, "Auxiliary": False, "Flavour": flavour,
                  "RealPath": True, "TextMode": False})
c["Misc"]["Tools"] = tools
B = c["Misc"]["Boot"]
B["HideAuxiliary"] = False
B["PickerAttributes"] = int(B.get("PickerAttributes", 0)) | 0x80   # icônes selon le « flavour »
plistlib.dump(c, open(f, "wb"))
PY

  if [ "$stub" = 1 ] && [ "$nsel" -gt 0 ]; then
    info "$(t hook_inst "$HOOK")"
    install_hook
  fi
  save_state
  local msg
  if grep -q '^main' "$WORK/plan.tsv"; then
    msg=$(t imp_done "$((total))" "$(main_entry_name)")
  else
    msg=$(t imp_done2 "$((total))")
  fi
  ui_msg "$(t done_title)" "$msg" ok
}

# mode compatibiliter
do_compat() {
  find_grub_dir || { ui_msg "$(t err_title)" "$(t no_grub)" error; return 1; }
  backup_esp || return 0
  mkdir -p "$ESP/EFI/BOOT"
  cp "$GRUBDIR/grubx64.efi" "$ESP/EFI/BOOT/BOOTX64.EFI" || die "$(t cp_fail BOOTX64.EFI)"
  if [ -f "$GRUBDIR/grub.cfg" ]; then cp "$GRUBDIR/grub.cfg" "$ESP/EFI/BOOT/grub.cfg"; fi
  (. /etc/os-release 2>/dev/null; echo "${NAME:-Linux}") > "$ESP/EFI/BOOT/.contentDetails"
  (. /etc/os-release 2>/dev/null; i=${ID:-linux}; echo "${i^}:Linux") > "$ESP/EFI/BOOT/.contentFlavour"
  COMPAT=1; save_state
  ui_msg "$(t done_title)" "$(t cp_done)" ok
}

# actions du menu
do_install() {
  check_secureboot || return 0
  backup_esp || return 0
  install_opencore
  create_boot_entry
  ui_msg "$(t done_title)" "$(t install_ok "$BRAND")" ok
  do_import
}

show_status() {
  local txt fw n
  fw=$(efibootmgr | grep -m1 -E ' (OpenCore Bootlinuxer by BecabDev|OpenCore)' || true)
  n=$(ls -d "$ESP"/EFI/OC/Tools/ocm-* 2>/dev/null | wc -l)
  txt="$(t st_esp "$ESP")"$'\n'
  if [ -f "$ESP/EFI/OC/OpenCore.efi" ]; then txt+="$(t st_oc_on)"$'\n'; else txt+="$(t st_oc_off)"$'\n'; fi
  txt+="$(t st_fw "${fw:-$(t st_fw_none)}")"$'\n'
  txt+="$(t st_tools "$n")"$'\n'
  if [ -f "$HOOK" ]; then txt+="$(t st_hook_on)"$'\n'; else txt+="$(t st_hook_off)"$'\n'; fi
  if [ "$COMPAT" = 1 ]; then txt+="$(t st_cp_on)"$'\n'; else txt+="$(t st_cp_off)"$'\n'; fi
  txt+="$(t st_bk "$STATE_DIR")"
  ui_msg "$(t st_title)" "$txt" info
}

EFIVARS=${EFIVARS:-/sys/firmware/efi/efivars}

# variables nvram laissées par OpenCore
oc_nvram_vars() {
  EFIVARS="$EFIVARS" CFG="$ESP/EFI/OC/config.plist" python3 - <<'PY'
import os, plistlib
d = os.environ["EFIVARS"]
if not os.path.isdir(d):
    raise SystemExit
OC = "-4d1fda02-38c7-4a6a-9cc6-4bcca8b30102"
found = {f for f in os.listdir(d) if f.lower().endswith(OC)}
cfg = os.environ["CFG"]
if os.path.exists(cfg):
    try:
        add = plistlib.load(open(cfg, "rb")).get("NVRAM", {}).get("Add", {})
        want = {("%s-%s" % (n, g)).lower() for g, names in add.items() for n in names}
        found |= {f for f in os.listdir(d) if f.lower() in want}
    except Exception:
        pass
print("\n".join(os.path.join(d, f) for f in sorted(found)))
PY
}

uninstall() {
  local fw nv n_tools oc_size sum n_fw labels
  fw=$(fw_oc_entries)
  nv=$(oc_nvram_vars | sed '/^$/d')
  n_tools=$(ls -d "$ESP"/EFI/OC/Tools/ocm-* 2>/dev/null | wc -l)
  oc_size=$(du -sh "$ESP/EFI/OC" 2>/dev/null | cut -f1)

  sum="$(t un_sum_head)"$'\n\n'
  if [ -n "$fw" ]; then
    n_fw=$(wc -l <<< "$fw")
    labels=$(awk -F'\t' '{printf "Boot%s (%s)  ", $1, $2}' <<< "$fw")
    sum+="$(t un_sum_fw "$n_fw" "$labels")"$'\n'
  else
    sum+="$(t un_sum_fw0)"$'\n'
  fi
  if [ -d "$ESP/EFI/OC" ]; then sum+="$(t un_sum_oc "${oc_size:-?}" "$n_tools")"$'\n'; fi
  if [ -f "$HOOK" ]; then sum+="$(t un_sum_hook "$HOOK")"$'\n'; fi
  if [ -n "$nv" ]; then sum+="$(t un_sum_nv "$(wc -l <<< "$nv")")"$'\n'; fi
  if [ -d "$BACKUP_DIR/EFI-BOOT" ]; then sum+="$(t un_sum_bk)"$'\n'
  elif [ "$COMPAT" = 1 ] && [ "$BOOT_EXISTED" = 0 ]; then sum+="$(t un_sum_bkrm)"$'\n'; fi
  if [ -n "$ORIG_BOOTORDER" ]; then sum+="$(t un_sum_ord "$ORIG_BOOTORDER")"$'\n'; fi
  sum+=$'\n'"$(t un_sum_keep)"$'\n\n'"$(t un_confirm)"
  ui_yesno "$(t un_title)" "$sum" 1 warn || return 0

  plain_begin
  local rep="" ok=1 num label f n existing order="" left cur

  while IFS=$'\t' read -r num label; do
    [ -n "$num" ] || continue
    if efibootmgr -b "$num" -B >/dev/null 2>&1; then info "$(t un_fw "$num")"; fi
  done <<< "$fw"
  if [ -z "$(fw_oc_entries)" ]; then rep+="[OK] $(t un_v_fw)"$'\n'
  else rep+="[!!] $(t un_v_fw_ko)"$'\n'; ok=0; fi

  if [ -n "$ORIG_BOOTORDER" ]; then
    existing=$(efibootmgr | sed -nE 's/^Boot([0-9A-Fa-f]{4}).*/\1/p')
    for n in ${ORIG_BOOTORDER//,/ }; do
      if grep -qix "$n" <<< "$existing"; then order+="${order:+,}$n"; fi
    done
    if [ -n "$order" ]; then efibootmgr -o "$order" >/dev/null 2>&1 || true; fi
  fi
  cur=$(efibootmgr | awk '/^BootOrder/{print $2}')
  rep+="[OK] $(t un_v_ord "${cur:-?}")"$'\n'

  if [ -n "$nv" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      chattr -i "$f" 2>/dev/null || true
      rm -f "$f"
    done <<< "$nv"
    left=$(oc_nvram_vars | sed '/^$/d' | wc -l)
    if [ "$left" = 0 ]; then rep+="[OK] $(t un_v_nv)"$'\n'
    else rep+="[!!] $(t un_v_nv_ko)"$'\n'; ok=0; fi
  fi

  if [ -f "$HOOK" ]; then
    rm -f "$HOOK"
    find_grub_cfg || true
    regen_grub >/dev/null 2>&1 || true
    if [ -n "$GRUB_CFG" ] && grep -q oc_default "$GRUB_CFG" 2>/dev/null; then
      rep+="[!!] $(t un_v_hook_ko)"$'\n'; ok=0
    else
      rep+="[OK] $(t un_v_hook)"$'\n'
    fi
  fi

  rm -rf "$ESP/EFI/OC"
  if [ -d "$ESP/EFI/OC" ]; then rep+="[!!] $(t un_v_oc_ko)"$'\n'; ok=0
  else rep+="[OK] $(t un_v_oc)"$'\n'; fi

  if [ -d "$BACKUP_DIR/EFI-BOOT" ]; then
    rm -rf "$ESP/EFI/BOOT"
    if cp -a "$BACKUP_DIR/EFI-BOOT" "$ESP/EFI/BOOT"; then rep+="[OK] $(t un_v_boot)"$'\n'; fi
  elif [ "$COMPAT" = 1 ] && [ "$BOOT_EXISTED" = 0 ]; then
    rm -rf "$ESP/EFI/BOOT"; rep+="[OK] $(t un_v_bootrm)"$'\n'
  elif [ -d /root/EFI-BOOT-backup ]; then
    if ui_yesno "$(t un_title)" "$(t un_manual)" 0; then
      rm -rf "$ESP/EFI/BOOT"
      if cp -a /root/EFI-BOOT-backup "$ESP/EFI/BOOT"; then rep+="[OK] $(t un_v_boot)"$'\n'; fi
    fi
  elif [ "$COMPAT" = 1 ]; then
    rep+="[!!] $(t un_v_boot0)"$'\n'
  fi

  rm -f "$STATE_DIR/icons.map" "$STATE_DIR/layout.tsv"
  if ui_yesno "$(t un_title)" "$(t un_delbk "$STATE_DIR")" 1; then rm -rf "$STATE_DIR"; NO_SAVE=1; fi

  ui_msg "$(t un_title)" "${rep}"$'\n'"$(t un_done)" "$([ "$ok" = 1 ] && echo ok || echo warn)"
}

# parametres OpenCore 
oc_cfg() {
  CFG="$ESP/EFI/OC/config.plist" OP=$1 FIELD=$2 VAL=${3:-} python3 - <<'PY'
import plistlib, os
f, op, fld, val = os.environ["CFG"], os.environ["OP"], os.environ["FIELD"], os.environ["VAL"]
c = plistlib.load(open(f, "rb"))
B = c.setdefault("Misc", {}).setdefault("Boot", {})
O = c.setdefault("UEFI", {}).setdefault("Output", {})
A = c["UEFI"].setdefault("AppleInput", {})
if op == "get":
    get = {"timeout": lambda: B.get("Timeout", 0),
           "show":    lambda: int(bool(B.get("ShowPicker", True))),
           "variant": lambda: B.get("PickerVariant", "Auto"),
           "pointer": lambda: int(bool(int(B.get("PickerAttributes", 0)) & 0x10)),
           "aux":     lambda: int(not B.get("HideAuxiliary", False)),
           "res":     lambda: O.get("Resolution", "Max"),
           "scale":   lambda: O.get("UIScale", -1)}
    print(get[fld]())
else:
    if fld == "timeout":   B["Timeout"] = int(val)
    elif fld == "show":    B["ShowPicker"] = (val == "1")
    elif fld == "variant": B["PickerVariant"] = val
    elif fld == "pointer":
        a = int(B.get("PickerAttributes", 0))
        B["PickerAttributes"] = (a | 0x10) if val == "1" else (a & ~0x10)
        A["PointerSupport"] = (val == "1")
        if val == "1":
            A["PointerSupportMode"] = "ASUS"
    elif fld == "aux":     B["HideAuxiliary"] = (val != "1")
    elif fld == "res":     O["Resolution"] = val
    elif fld == "scale":   O["UIScale"] = int(val)
    plistlib.dump(c, open(f, "wb"))
PY
}
oc_set() { cp "$ESP/EFI/OC/config.plist" "$ESP/EFI/OC/config.plist.bak" 2>/dev/null; oc_cfg set "$1" "$2"; }
onoff()  { if [ "$1" = 1 ]; then t v_on; else t v_off; fi; }

set_bool() {
  local def=1
  if [ "$3" = 1 ]; then def=0; fi
  if ui_yesno "$(t set_title)" "$(t "$2")" "$def"; then oc_set "$1" 1
  elif [ "$UI_RESULT" = 1 ]; then oc_set "$1" 0; fi
}
set_timeout() {
  ui_input "$(t to_title)" "$(t to_prompt)" "$(oc_cfg get timeout)" || return 0
  if [[ $UI_RESULT =~ ^[0-9]+$ ]]; then oc_set timeout "$UI_RESULT"
  else ui_msg "$(t err_title)" "$(t s_bad "$UI_RESULT")" error; fi
}
set_variant() {
  local -a th=(Auto); local line
  while IFS= read -r line; do th+=("$line"); done < <(
    find "$ESP/EFI/OC/Resources/Image" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' 2>/dev/null | tr '/' '\\' | sort)
  ui_menu "$(t set_title)" "$(t s_variant_s)" 0 "${th[@]}" || return 0
  oc_set variant "${th[$UI_RESULT]}"
}
set_res() {
  local -a opts=(Max 1920x1080 2560x1440 3840x2160); local v re='^(Max|[0-9]+x[0-9]+(@[0-9]+)?)$'
  ui_menu "$(t set_title)" "$(t s_res_s)" 0 "${opts[@]}" "$(t s_res_cust)" || return 0
  if [ "$UI_RESULT" -ge ${#opts[@]} ]; then
    ui_input "$(t set_title)" "$(t s_res_p)" "" || return 0
    v=$UI_RESULT
  else
    v=${opts[$UI_RESULT]}
  fi
  if [[ $v =~ $re ]]; then oc_set res "$v"
  else ui_msg "$(t err_title)" "$(t s_bad "$v")" error; fi
}
set_scale() {
  ui_menu "$(t set_title)" "$(t s_scale_s)" 0 "$(t v_auto)" "1x" "2x" || return 0
  case $UI_RESULT in 0) oc_set scale -1 ;; 1) oc_set scale 0 ;; 2) oc_set scale 1 ;; esac
}
set_reset() {
  if ui_yesno "$(t set_title)" "$(t s_reset_q)" 1 warn; then
    oc_set timeout 10; oc_set show 1; oc_set variant Auto; oc_set pointer 1
    oc_set aux 1; oc_set res Max; oc_set scale -1
  fi
}

do_settings() {
  [ -f "$ESP/EFI/OC/config.plist" ] || { ui_msg "$(t err_title)" "$(t no_oc)" error; return 1; }
  local cur=0 to sh va po ax rs sc tl
  while true; do
    to=$(oc_cfg get timeout); sh=$(oc_cfg get show); va=$(oc_cfg get variant)
    po=$(oc_cfg get pointer); ax=$(oc_cfg get aux); rs=$(oc_cfg get res); sc=$(oc_cfg get scale)
    if [ "$to" = 0 ]; then tl=$(t v_forever); else tl=$(t v_secs "$to"); fi
    case $sc in -1) sc=$(t v_auto) ;; 0) sc=1x ;; 1) sc=2x ;; esac
    if [ "$va" = Auto ]; then va=$(t v_auto); fi
    ui_menu "$(t set_title)" "$(t set_sub)" "$cur" \
      "$(t s_timeout "$tl")" "$(t s_show "$(onoff "$sh")")" "$(t s_variant "$va")" \
      "$(t s_pointer "$(onoff "$po")")" "$(t s_aux "$(onoff "$ax")")" "$(t s_res "$rs")" \
      "$(t s_scale "$sc")" "$(t s_reset)" "$(t s_back)" || return 0
    cur=$UI_RESULT
    case $cur in
      0) set_timeout ;;
      1) set_bool show s_show_q "$sh" ;;
      2) set_variant ;;
      3) set_bool pointer s_pointer_q "$po" ;;
      4) set_bool aux s_aux_q "$ax" ;;
      5) set_res ;;
      6) set_scale ;;
      7) set_reset ;;
      *) return 0 ;;
    esac
  done
}

distro_flavour() { local i; i=$(. /etc/os-release 2>/dev/null; echo "${ID:-linux}"); echo "${i^}:Linux"; }

list_icons() {
  find "$ESP/EFI/OC/Resources/Image" -type f -iname '*.icns' -printf '%f\n' 2>/dev/null \
    | sed 's/\.icns$//I' \
    | grep -vxE 'Background|Cursor|Selected|Selector|Left|Right|Dot|Password|Button|Checkmark|Pointer' \
    | sort -u
}

do_lang() {
  ui_menu "$(t lang_title)" "$(t lang_sub)" 0 "Français" "English" || return 0
  if [ "$UI_RESULT" = 1 ]; then LANG_UI=en; else LANG_UI=fr; fi
  save_state
}

run() {
  ( "$@"; save_state )
  if [ -f "$STATE_FILE" ]; then load_state
  else ORIG_BOOTORDER=""; OC_BOOTNUM=""; COMPAT=0; BOOT_EXISTED=0; GRUBDIR=""; fi
}

main() {
  [ -t 0 ] && [ -t 1 ] || { echo "$(t need_tty)" >&2; exit 1; }
  ensure_python
  load_state; write_tui

  if [ -z "$LANG_UI" ]; then LANG_UI=fr; do_lang; fi

  if [ "$EUID" -ne 0 ]; then
    ui_msg "$(t err_title)" "$(t need_root "$0")" error
    clear; exit 1
  fi
  if [ ! -d /sys/firmware/efi ]; then
    ui_msg "$(t err_title)" "$(t not_uefi)" error
    clear; exit 1
  fi

  check_deps || { clear; exit 1; }

  find_esp; save_state

  local -a keys=(m1 m2 m3 m4 m5 m6 m7)
  local -a fns=(do_install do_import do_compat do_settings show_status uninstall do_lang)
  local -a items; local c i
  while true; do
    items=()
    for i in "${!keys[@]}"; do items+=("$((i+1)). $(t "${keys[$i]}")"); done
    items+=("0. $(t m0)")
    ui_menu "$(t menu_title)" "$(t menu_sub "$ESP")" 0 "${items[@]}" || break
    c=$UI_RESULT
    if [ "$c" -ge ${#fns[@]} ]; then break; fi
    run "${fns[$c]}"
  done
  clear
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi