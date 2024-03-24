Scriptname IH_PlayerAliasScript extends ReferenceAlias
;/I forgot to ensure that this alias is actually getting filled in existing
; saves, which it wasn't (SM only fills aliases on quest restart), so now I
; have to abandon this script and use a new one. This is so that:
;  a) there won't be (harmless) Papyrus errors in existing saves, and
;  b) so I can use the OnInit() event in the new script to fill the alias /;