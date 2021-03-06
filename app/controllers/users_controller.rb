# This file is part of the OpenWISP User Management System
#
# Copyright (C) 2010 CASPUR (Davide Guerri d.guerri@caspur.it)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class UsersController < ApplicationController
  before_filter :require_operator
  before_filter :load_user, :except => [ :index, :new, :create, :ajax_search, :browse, :search, :find ]

  access_control do
    default :deny
    
    allow :users_browser,    :to => [ :show, :browse, :ajax_search, :ajax_accounting_search, :createdownload, :createPDF ]
    allow :users_registrant, :to => [ :new, :create, :createdownload, :createPDF ]
    allow :users_manager,    :to => [ :new, :create, :edit, :update, :createdownload, :createPDF ]
    allow :users_destroyer,  :to => [ :destroy ]
    allow :users_finder,     :to => [ :find, :search, :show, :createdownload, :createPDF]
    allow :stats_viewer,     :to => [ :index ]
  end

  STATS_PERIOD = 14

  def load_user
    @user = User.find(params[:id])
  end
  
  def index
  end
  
  def new
    @user = User.new( :eula_acceptance => true, :privacy_acceptance => true, :state => 'Italy', :verification_method => User::VERIFY_BY_DOCUMENT )
    @user.verified = true
    @user.radius_group_ids = [ RadiusGroup::machines_group ]
    @countries = Country.find :all, :conditions => "disabled = 'f'", :order => :printable_name
    @mobile_prefixes = MobilePrefix.find :all, :conditions => "disabled = 'f'", :order => :prefix
    @radius_groups = RadiusGroup.all
  end
  
  def create
    @user = User.new(params[:user])   

    # Parameter anti-tampering
    unless current_operator.has_role? 'users_manager'
      @user.radius_group_ids = [ RadiusGroup::machines_group ]
      @user.verified = @user.active = true
    end
    
    @countries = Country.find :all, :conditions => "disabled = 'f'", :order => :printable_name
    @mobile_prefixes = MobilePrefix.find :all, :conditions => "disabled = 'f'", :order => :prefix
    @radius_groups = RadiusGroup.all

    if @user.save
      current_account_session.destroy unless current_account_session.nil?
            
      unless current_operator.has_role? 'users_manager'
       # redirect_to new_user_url
       redirect_to users_browse_path
      else
        redirect_to users_url
        
      end
    else
      render :action => :new
    end
  end
  
  def show
  end
 
  def edit
    @countries = Country.find :all, :conditions => "disabled = 'f'", :order => :printable_name
    @mobile_prefixes = MobilePrefix.find :all, :conditions => "disabled = 'f'", :order => :prefix
    @radius_groups = RadiusGroup.all
  end
  
  def createdownload
  	user = User.find(params[:id])
	
	cpe= CpeTemplate.find(user.xuser.inst_cpe_modello);
	template = cpe.template
	template=template.gsub("<CPE_NAME>",user.xuser.inst_cpe_username)
	template=template.gsub("<CPE_PASSWORD>",user.xuser.inst_cpe_password)
	file_name = cpe.name,".txt"
	t = Tempfile.new("tmp-cpe_configuration_file-#{Time.now}")
	t.write(template)
	t.close
	send_file t.path, :type => 'text/plain; charset=utf-8',
                             :disposition => 'attachment',
                             :filename => file_name
  end
  require 'pdf/writer'
  require 'pdf/simpletable'
  def createPDF
  	
  	user = User.find(params[:id])
  	pdf = PDF::Writer.new(:paper => "A4",:orientation => :portrait)
  	encoding = {
		  :encoding => "WinAnsiEncoding",
		  :differences => {
			    215 => "multiply", # mappa il byte 215 con il carattere "x"
			    148 => "copyright" 
		  }
	}    
  	
  	pdf.margins_pt(36, 54, 120, 54)
  	pdf.start_page_numbering(300, pdf.bottom_margin-30, 9, nil, nil, 1)
   	pdf.select_font 'Helvetica', encoding
   	
   	x = pdf.page_width - pdf.right_margin # flush right
	y = pdf.page_height - pdf.top_margin  # flush top
  	# Draw a box at the margin positions.
	x = pdf.absolute_left_margin
	w = pdf.absolute_right_margin - x
  	# or pdf.margin_width
	y = pdf.absolute_bottom_margin
	h = pdf.absolute_top_margin - y
  	# or pdf.margin_height
	
   	pdf.image (Rails.root.to_s + "/public/images/logo-testo.jpg", :justification => :left,:resize => 0.5)
   	pdf.move_pointer(-20)
        
        pdf.fill_color    Color::RGB::Black
      	
        pdf.text "<b>Meshcom Italia s.a.s.</b>\nVia Giacomo Peroni, snc (Tecnopolo Tiburtino) - 00131 Roma - Tel. +39 06 90289104\nVia Duca del Mare snc - 04016 Sabaudia LT - Tel +39 0773 1870870\nREA RM-1220798 - CF/PI 10250931002\ne-mail: info@meshcom.it - Web: www.meshcom.it", :font_size => 6 , :justification => :full, :left => 250
        pdf.line(0, pdf.y-5, pdf.page_width, pdf.y-5)
   	# à pdf.text("\xe1")
   	# A' \xc0
   	# è  \xe8
   	# E' \xc8
   	# ò  \xf2
   	# O' \xd2
   	# ì  \xec
   	# I' \xcc
   	# ù  \xf9
   	# U' \xd9
   	pdf.move_pointer(34)
   	#numero contratto e tipo
   	pdf.text "<b>Contratto di Utenza "+ (user.xuser.is_company ? "Persone giuridiche" : "Persone fisiche") +"</b> - <b>Codice utente:</b> "+sprintf('%010d', user.id), :font_size => 10, :justification => :left
   	
   	
   	pdf.move_pointer(12)
   	#Dati azienda
   	if user.xuser.is_company
	   	pdf.text "<b>Informazioni Azienda</b>", :font_size => 8, :justification => :left, :leading => 12
	   	
	   	pdf.text "<C:bullet /><b>Ragione sociale:</b> "+user.xuser.pg_ragione_sociale, :font_size => 8
	   	pdf.text "<C:bullet /><b>Partita Iva:</b> "+user.xuser.pg_partita_iva
	   	pdf.text "<C:bullet /><b>Indirizzo legale:</b> "+user.xuser.pg_indirizzo+" "+user.xuser.pg_cap+" - "+user.xuser.pg_comune
   		pdf.text " "
   	end
   	#Dati personali
   	pdf.text "<b>Informazioni Utente</b>", :font_size => 8, :justification => :left, :leading => 12
   	pdf.text "<C:bullet /><b>Cognome:</b> "+user.surname, :font_size => 8,:left => 20
   	pdf.text "<C:bullet /><b>Nome:</b> "+user.given_name,:left => 20
   	pdf.text "<C:bullet /><b>Nato il:</b> "+user.birth_date.strftime( '%d %m %Y' ) + " <b>a:</b> "+user.xuser.pf_luogo_di_nascita,:left => 20
   	pdf.text "<C:bullet /><b>Residente in:</b> "+ user.address + " " + user.zip + " - " + user.city,:left => 20
   	pdf.text "<C:bullet /><b>Codice fiscale:</b> "+ user.xuser.pf_cf,:left => 20
   	pdf.text "<C:bullet /><b>Telefono:</b> "+user.mobile_prefix+" "+user.mobile_suffix,:left => 20
   	pdf.text "<C:bullet /><b>IBAN:</b> "+user.xuser.iban,:left => 20
   	#Dati installazione
   	pdf.text "<b>Dati di installazione</b>", :font_size => 8, :justification => :left, :leading => 12
   	pdf.text "Il servizio sar\xe1 fornito presso l'indirizzo fornito dal cliente:" , :font_size => 6
	pdf.text "<b>"+user.xuser.inst_indirizzo+ " " + user.xuser.inst_cap+"</b>", :justification => :center, :leading => 12, :font_size => 8
	# Contratto
	pdf.text "<b>Accettazione condizioni di contratto e trattamento dati personali</b>", :font_size => 8, :justification => :left, :leading => 12
	pdf.text "L\'Utente, congiuntamente alla seguente accettazione, dichiara espressamente di aver preso visione e di approvare l\'informativa seguente:",:font_size => 6, :justification => :left 
	pdf.text "<C:disc /><b>Condizioni Generali di Fornitura e Abbonamento ai Servizi</b>",:left => 20
	pdf.text "<C:disc /><b>Condizioni Tecnico/economiche di cui al sito (www.meshcom.it)</b>",:left => 20
	pdf.text "<b>Informative ex art. 52, 53, 64 e ss. e 5 D.Legs. 206/2005 ed art. 7 D. Legs. 70/2003.</b>",:font_size => 8, :justification => :left , :leading => 12
	pdf.text "Ai sensi di quanto previsto dagli art.52,53 e 64 e ss.D.Legs.206/2005 l\'Utente prende atto che:\n",:font_size => 6, :justification => :full
	pdf.text "<b>1.</b> fornitore del servizio di cui al presente Modulo di Adesione, \xe8 la societ\xe1 <b>Meshcom Italia</b> con sede in Roma via Giacomo Peroni snc cap 00131, CF/P.IVA 10250931002, REA RM-1220798, Tel. 06 90289104, Fax 06 90280454, info@meshcom.it;\n<b>2.</b> tramite il Servizio fornito, l\'Utente pu\xf2 accedere alla Rete Wi-Fi e, tramite questa, ad Internet;\n<b>3.</b> ogni costo indicato nel presente Modulo di Adesione \xe8 comprensivo di IVA, e di ogni altra tassa e/o imposta;\n<b>4.</b> i costi di attivazione includono le spese di consegna, e con esse la spedizione ed il trasporto fino al luogo indicato dall\'Utente;\n<b>5.</b> l\'offerta ed i relativi prezzi sono validi fino ad eventuale modifica da comunicarsi all\'Utente secondo le modalit\xe1 previste dalle Condizioni Generali di Fornitura e Abbonamento ai Servizi;\n<b>6. </b>il pagamento della fornitura e dell\'abbonamento ai servizi avviene mediante R.I.D.\n<b>7.</b> il Contratto ha durata minima annuale a decorrere dall\'attivazione del Servizio, e sar\xe1 automaticamente rinnovato di anno in anno, salvo disdetta da inviarsi da parte dell\'Utente con preavviso di almeno 30 giorni.\n<b>8.</b> qualora il contratto sia sottoscritto dall\'Utente per via telematica avr\xe1 la facolt\xe1 di recedere, senza obbligo di indicarne i motivi e/o di pagare alcuna penalit\xe1, entro il termine di 10 giorni lavorativi dalla conclusione di esso fatto salvo il caso in cui l\'attivazione e la fornitura dei servizi sia iniziata, con l\'accordo dell\' Utente, prima della scadenza del termine dei 10 giorni previsti dall\'art. 64 comma 1) del D.Lsg. 206/2005 salvo quanto stabilito agli art. 65 comma 3), 4) e5)],cos\xec come indicato all\'art. 55 comma2) del D.Lsg. 206/2005;\n<b>9.</b> che i diritti di recesso di cui alle precedenti clausole si esercitano con l\'invio, entro il termine previsto, di una comunicazione scritta alla indicata sede della Meshcom, mediante lettera raccomandata con avviso di ricevimento con allegata copia del documento di identit\xe1. La comunicazione pu\xf2 essere inviata, entro lo stesso termine, anche mediante posta elettronica ad info@meshcom.it a condizione che sia confermata mediante lettera raccomandata con avviso di ricevimento entro le 48 ore successive.\n<b>10.</b> che, in caso di esercizio del diritto di recessione entro i 10 giorni dalla conclusione del contratto, e qualora nel frattempo abbia ricevuto il prodotto accessorio richiesto, l\'Utente dovr\xe1 contestualmente restituirlo a <b>Meshcom Italia</b> a proprie spese, integro e non usato. Qualora il prodotto sia ricevuto dall\'Utente successivamente all\'esercizio del diritto di recesso, egli dovr\xe1 restituirlo sempre a proprie spese, integro e non usato entro 3 giorni dal suo ricevimento.\n<b>11.</b> eventuali reclami attinenti al servizio, alla fatturazione e agli altri aspetti contrattuali possono essere inviati a mezzo raccomandata presso la sede di Meshcom Italia - vedi sito www.meshcom.it - pi\xf9 vicina all\'Utente il servizio di assistenza tecnica \xe8 prestato da Meshcom Italia mediante i propri operatori, cui inoltrare le segnalazioni al numero telefonico - vedi sito www.meshcom.it - attivo negli orari 10:00-18:00.\n<b>12.</b> i beni informatici commercializzati unitamente al Servizio sono comunque coperti dalla garanzia convenzionale rilasciata dal produttore della durata di 12 mesi, ed alla garanzia legale di conformit\xe1 di cui al DL24/02, di cui per esteso nelle Condizioni Generali.",:font_size => 6, :justification => :full
	
	pdf.text "<b>Informativa sul trattamento dei dati personali</b>", :font_size => 8, :justification => :left, :leading => 12
	pdf.text "Gentile Utente, Desideriamo informarLa che i Suoi dati personali - raccolti direttamente presso di Lei, presso le nostre sedi o altrimenti acquisiti nell\'ambito della nostra attivit\xe1 - saranno utilizzati da <b>Meshcom Italia</b> nel pieno rispetto dei principi fondamentali dettati dalle direttive 95/46/CE, 97/66/CE, 97/7/CE, 2002/58/CE e dal D.lgs 196/03 (codice in materia di protezione dei dati personali).",:font_size => 6, :justification => :full
	
	pdf.text "<b>Trattamenti e relativi scopi</b>", :font_size =>8, :leading => 12
	pdf.text "I dati verranno trattati per finalit\xe1 istituzionali connesse o strumentali all\'attivit\xe1 di Meshcom Italia, e quindi: per dare esecuzione al Servizio o ad una o pi\xf9 operazioni contrattualmente convenuti, nonch\xe8 per proporre le prestazioni supplementari eventualmente sperimentate ed attivate dopo la sottoscrizione dell\'Abbonamento, nonch\xe8 per le attivit\xe1 di fidelizzazione dell\'Utente diverse da quelle di cui al successivo punto 4; per eseguire, in generale, obblighi di legge; per esigenze di tipo operativo e gestionale interne a Meshcom Italia; nonch\xe8, previo Suo consenso, per la comunicazione di informazioni commerciali tramite telefono, posta, comunicazione in fattura, posta elettronica, SMS relative a nuove offerte di prodotti e servizi Meshcom Italia e/o di societ\xe1 con le quali si abbiano stipulato accordi commerciali, e per verificare il livello di soddisfazione dell\'Utente su prodotti e servizi forniti da Meshcom Italia;", :font_size => 6, :justification => :full
	
	pdf.text "<b>Consenso al trattamento dei dati personali</b>", :font_size => 8, :leading => 12
	pdf.text "Il conferimento dei Suoi dati \xe8 facoltativo. Tuttavia, in caso di rifiuto del consenso per gli scopi 1, 2 e 3, <b>Meshcom Italia</b> si trover\xe1 nell\'impossibilit\xe1 di fornirLe il Servizio. In caso di mancato consenso, invece, per gli scopi di cui al punto 4, non vi sar\xe1 alcuna conseguenza.",:font_size => 6
	
	pdf.text "<b>Modalit\xe1 del trattamento</b>",:font_size => 8, :justification => :left, :leading => 12
	pdf.text "Il trattamento dei dati avverr\xe1 mediante strumenti idonei a garantirne la sicurezza nonch\xe8 la riservatezza e potr\xe1 essere effettuato anche mediante strumenti automatizzati atti a memorizzare, gestire e trasmettere i dati stessi. I dati saranno conservati presso la nostra sede operativa in Roma 00131 via Giacomo Peroni snc per i tempi prescritti dalle norme di legge.",:font_size => 6, :justification => :full
	
	pdf.text "<b>Titolare e responsabile del trattamento</b>",:font_size => 8, :justification => :left, :leading => 12
	pdf.text "Titolare del trattamento \xe8 <b>Meshcom Italia</b>, avente sede legale in Roma alla via Giacomo Peroni snc cap 00131. Responsabili del trattamento dei dati personali sono i funzionari e i soggetti elencati nel prospetto disponibile presso la sede, in relazione al rispettivo settore di competenza.",:font_size => 6, :justification => :full
	
	pdf.text "<b>Diritti del titolare</b>",:font_size => 8, :justification => :left, :leading => 12
	pdf.text "Sono garantiti i diritti di cui all\'art. 7 Dlgs. 196/2003, che di seguito si riporta per esteso. Per l\'esercizio di tali diritti, l\'interessato dovr\xe1 rivolgere richiesta scritta a Meshcom Italia\n\n",:font_size => 6, :justification => :full	
	pdf.text "<b>Art 7-Diritto di accesso ai dati personali ed altri diritti</b>"
	pdf.text "<b>1.</b> L'interessato ha diritto di ottenere la conferma dell'esistenza o meno di dati personali che lo riguardano, anche se non ancora registrati, e la loro comunicazione in forma intelligibile.\n<b>2.</b> L'interessato ha diritto di ottenere l'indicazione:",:left => 10
	pdf.text "<b>a)</b> dell'origine dei dati personali;\n<b>b)</b> delle finalit\xe1 e modalit\xe1 del trattamento;\n<b>c)</b>della logica applicata in caso di trattamento effettuato con l'ausilio di strumenti elettronici;\n<b>d)</b> degli estremi identificativi del titolare, dei responsabili e del rappresentante designato ai sensi; dell'articolo 5 , comma 2;\n<b>e)</b> dei soggetti o delle categorie di soggetti ai quali i dati personali possono essere comunicati o che possono venirne a conoscenza in qualit\xe1 di rappresentante designato nel territorio dello Stato, diresponsabili o incaricati.", :left => 20
	pdf.text "<b>3.</b> L'interessato ha diritto di ottenere:",:left => 10
	pdf.text "<b>a)</b> l'aggiornamento, la rettifica ovvero, quando vi ha interesse, l'integrazione dei dati;\n<b>b)</b> la cancellazione, la trasformazione in forma anonima o il blocco dei dati trattati in violazione di legge, compresi quelli di cui non \xe8 necessaria la conservazione in relazione agli scopi per i quali i dati sono stati raccolti o successivamente trattati;\n<b>c)</b> l'attestazione che le operazioni di cui alle lettere a) e b) sono state portate a conoscenza, anche per quanto riguarda il loro contenuto, di coloro ai quali i dati sono stati comunicati o diffusi, eccettuato il caso in cui tale adempimento si rivela impossibile o comporta un impiego di mezzi manifestamente sproporzionato rispetto al diritto tutelato.", :left => 20
	pdf.text "<b>4.</b> L'interessato ha diritto di opporsi, in tutto o in parte:",:left => 10
	pdf.text "<b>a)</b> per motivi legittimi al trattamento dei dati personali che lo riguardano, ancorch\xe8 pertinenti allo scopo della raccolta;\n<b>b)</b>al trattamento di dati personali che lo riguardano a fini di invio di materiale pubblicitario o di vendita diretta o per il compimento di ricerche di mercato o di comunicazione commerciale.", :left => 20
	pdf.text "Il sottoscritto, per quanto riguarda i trattamenti di cui al punto 4, finalizzati ad indagini ed analisi di mercato:"
	pdf.text "[ ] Autorizza il trattamento                                  [ ] Non autorizza il trattamento", :leading => 20
	
   	t= Time.now
   	pdf.text "<b>Data:</b> "+t.strftime("%d/%m/%Y %H:%M"), :font_size => 8, :justification => :full, :leading => 20
	
	pdf.text "<b>Firme per accettazione delle condizioni di contratto:</b>", :font_size => 6, :leading => 20
	
	firme_data = []
    
	firme_data << { "Contratto" => "Firma per accettazione delle condizioni generali di contratto ", "Dati" => "Firma per accettazione delle clausole relative al trattamento dei dati personali ", "RID" =>  "Firma per accettazione all'attivazione del prelievo automatico mensile RID sul conto indicato IBAN" }  
	firme_data << { "Contratto" => "\n\n ", "Dati" => "\n\n ", "RID" =>  "\n\n" }

	firme = PDF::SimpleTable.new
	firme.font_size = 6
	firme.position      = 54
	firme.orientation   = :right
	firme.width = 500
	firme.show_headings = false
	firme.column_order = ["Contratto", "Dati", "RID"]
	firme.data = firme_data
	firme.render_on(pdf)
	
	
   	send_data pdf.render, :filename => 'meshcom-contratto.pdf', :type => "application/pdf"
  end
  
  def update
    # Parameter anti-tampering
    params[:user][:radius_group_ids] = nil unless current_operator.has_role? 'users_manager'
    
    @countries = Country.find :all, :conditions => "disabled = 'f'", :order => :printable_name
    @mobile_prefixes = MobilePrefix.find :all, :conditions => "disabled = 'f'", :order => :prefix
    @radius_groups = RadiusGroup.all
    
    if @user.update_attributes(params[:user])
      current_account_session.destroy unless current_account_session.nil?
            
      flash[:notice] = I18n.t(:Account_updated)
      # redirect_to user_url
      redirect_to users_browse_path
    else
      render :action => :edit
    end
  end

  def destroy
    @user.destroy
    # redirect_to users_url
    redirect_to users_browse_path
  end

  def find
    if params[:user] && params[:user][:query]
      query = params[:user][:query]
      found_users = User.find_all_by_user_phone_or_mail(query)

      if found_users.count == 1
        @user = found_users.first
        redirect_to @user
      elsif found_users.count > 1
        flash[:error] = I18n.t(:Too_many_search_results)
        render :action => :search
      else
        flash[:error] = I18n.t(:User_not_found)
        render :action => :search
      end
    else
      flash[:error] = I18n.t(:User_not_found)
      render :action => :search
    end
  end

  def search
  end

  def browse
	## MODIFIED: Added 4 lines
	respond_to do |format|
	  format.html # browse.html.erb
	  format.xml  { render :xml => User.all }
    end
	## END MODIFIED
  end

  def ajax_search
    items_per_page = Configuration.get('default_user_search_results_per_page')

    sort = case params[:sort]
      when 'registered_at'      then "created_at"
      when 'username'           then "username"
      when 'given_name'         then "given_name"
      when 'surname'            then "surname"
      when 'state'              then "state"
      when 'city'               then "city"
      when 'address'            then "address"
      when 'verified'           then "verified"
      when 'active'             then "active"
      when 'registered_at_rev'  then "created_at DESC"
      when 'username_rev'       then "username DESC"
      when 'given_name_rev'     then "given_name DESC"
      when 'surname_rev'        then "surname DESC"
      when 'state_rev'          then "state DESC"
      when 'city_rev'           then "city DESC"
      when 'address_rev'        then "address DESC"
      when 'verified_rev'       then "verified DESC"
      when 'active_rev'         then "active DESC"
    end
    if sort.nil?
      params[:sort] = "registered_at_rev"
      sort = "created_at DESC"
    end  

    search = params[:search]
    page = params[:page].nil? ? 1 : params[:page]
    
    unless search.nil?
      search.gsub(/\\/, '\&\&').gsub(/'/, "''")
      conditions = [ "xusers.operator_id= 2  AND (given_name LIKE ? OR surname LIKE ? OR username LIKE ? OR CONCAT(mobile_prefix,mobile_suffix) LIKE ? OR CONCAT_WS(' ', given_name, surname) LIKE ? OR CONCAT_WS(' ', surname, given_name) LIKE ?)", "%#{search}%","%#{search}%","%#{search}%","%#{search}%","%#{search}%","%#{search}%" ] 
    else
      conditions = ["xusers.operator_id= "+ current_operator.id.to_s()]
    end

    @total_users = User.count :conditions => conditions, :joins => :xuser
    @users = User.paginate :page => page, :order => sort, :conditions => conditions, :per_page => items_per_page, :joins => :xuser

    render :partial => "list", :locals => { :action => 'ajax_search', :users => @users, :total_users => @total_users }
  end

  def ajax_accounting_search
    items_per_page = Configuration.get('default_radacct_results_per_page')

    sort = case params[:sort]
      when 'acct_start_time'          then "AcctStartTime"
      when 'acct_stop_time'           then "AcctStopTime"
      when 'acct_input_octets'       then "AcctInputOctets"
      when 'acct_output_octets'      then "AcctOutputOctets"
      when 'calling_station_id'       then "CallingStationId"
      when 'framed_ip_address'        then "FramedIPAddress"
      when 'acct_start_time_rev'      then "AcctStartTime DESC"
      when 'acct_stop_time_rev'       then "AcctStopTime DESC"
      when 'acct_input_octets_rev'   then "AcctInputOctets DESC"
      when 'acct_output_octets_rev'  then "AcctOutputOctets DESC"
      when 'calling_station_id_rev'   then "CallingStationId DESC"
      when 'framed_ip_address_rev'    then "FramedIPAddress DESC"
    end
    if sort.nil?
      params[:sort] = "acct_start_time_rev"
      sort = "AcctStartTime DESC"
    end

    page = params[:page].nil? ? 1 : params[:page]

    @total_accountings =  @user.radius_accountings.count
    @radius_accountings = @user.radius_accountings.paginate :page => page, :order => sort, :per_page => items_per_page

    render :partial => "common/radius_accounting_list", :locals => { :action => 'ajax_accounting_search', :accountings => @radius_accountings, :total_accountings => @total_accountings } 
  end
end
