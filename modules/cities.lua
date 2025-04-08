-------------------------------------------------
--------------------- CITIES --------------------
-------------------------------------------------

local timer = require("timer")

------------
-- EVENTS --
------------

local function Cities(client) -- ready event
	local cities = {"Rondinha","Campo Novo","Brochier","Nova Araçá","Erval Grande","Nova Esperança do Sul","Mato Leitão","Caiçara","Barracão","Liberato Salzano","Viadutos","Três Palmeiras","Caibaté","Mata","Humaitá","Vicente Dutra","Cacique Doble","Muçum","Chuvisca","Pinheirinho do Vale","Ibiaçá","Fortaleza dos Valos","Riozinho","Doutor Maurício Cardoso","São João da Urtiga","Tabaí","São José do Hortêncio","Miraguaí","Maçambará","Vila Maria","Porto Lucena","David Canabarro","Marcelino Ramos","Pareci Novo","Fazenda Vilanova","Novo Barreiro","Barra do Quaraí","Maximiliano de Almeida","São José dos Ausentes","Aceguá","Ilópolis","Ciríaco","Arambaré","Capivari do Sul","Passa-Sete","Marques de Souza","Mariana Pimentel","Chiapetta","Água Santa","Quinze de Novembro","Vila Nova do Sul","Cotiporã","Pinhal Grande","Cerro Branco","Jaboticaba","Putinga","Pejuçara","Ibarama","Ibirapuitã","Jaquirana","Tunas","Alegria","Vila Flores","Paim Filho","Campos Borges","Novo Cabrais","São Pedro da Serra","Nova Roma do Sul","Turuçu","Severiano de Almeida","Áurea","Jari","Jacutinga","Gramado Xavier","Pontão","Braga","Tio Hugo","São Valentim","Vitória das Missões","Colorado","Campestre da Serra","Esperança do Sul","Itatiba do Sul","Novo Machado","Esmeralda","Monte Alegre dos Campos","Nova Alvorada","Barra do Guarita","Vale Verde","Mampituba","Capão do Cipó","Taquaruçu do Sul","Westfália","Dois Lajeados","Imigrante","Dona Francisca","Presidente Lucena","Alto Feliz","Morrinhos do Sul","Estrela Velha","São Pedro do Butiá","Nova Candelária","Erebango","Nova Bréscia","Ernestina","Caseiros","Itacurubi","Camargo","Pinhal","Capitão","São Jorge","Muitos Capões","Salvador das Missões","Rio dos Índios","Coronel Barros","São Martinho da Serra","Dilermando de Aguiar","Vista Gaúcha","Victor Graeff","Boa Vista do Sul","Charrua","Três Forquilhas","Mormaço","São Domingos do Sul","Derrubadas","Pinto Bandeira","Centenário","Sede Nova","Cristal do Sul","Garruchos","Entre Rios do Sul","Senador Salgado Filho","Coxilha","Vista Alegre","São João do Polêsine","Itati","Eugênio de Castro","Lajeado do Bugre","Arroio do Padre","Santa Margarida do Sul","Três Arroios","Saldanha Marinho","Fagundes Varela","Dom Pedro de Alcântara","Monte Belo do Sul","Toropi","Mato Castelhano","São Valério do Sul","Herveiras","Faxinalzinho","Dezesseis de Novembro","Quevedos","Barra Funda","Sagrada Família","Maratá","Colinas","São José do Inhacorá","Forquetinha","Cerro Grande","São José das Missões","Santo Expedito do Sul","Nova Pádua","Rolador","São José do Sul","Boa Vista do Incra","Pirapó","Lagoa Bonita do Sul","São Vendelino","Pinhal da Serra","Boa Vista do Cadeado","Coqueiros do Sul","São Valentim do Sul","Poço das Antas","Nova Ramada","Travesseiro","Bozano","Silveira Martins","Novo Tiradentes","Paulo Bento","Porto Mauá","Bom Progresso","Santo Antônio do Palma","Dois Irmãos das Missões","Santo Antônio do Planalto","Benjamin Constant do Sul","Vila Lângaro","Pedras Altas","Nova Boa Vista","Jacuizinho","Protásio Alves","Gramado dos Loureiros","Inhacorá","Vanini"}
	while true do
		client:setActivity(cities[math.random(#cities)]..", Rio Grande do Sul, Brasil")
		timer.sleep(math.random(14400000,28800000))
	end
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	ready = {Cities},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn