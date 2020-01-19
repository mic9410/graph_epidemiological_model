import Pkg;
Pkg.add("Distributions")
Pkg.add("LightGraphs")
Pkg.add("MetaGraphs")
Pkg.add("GraphPlot")
Pkg.add("Compose")
Pkg.add("Colors")
using Distributions
using LightGraphs #wygodna biblioteka do tworzenia grafow, jej dokumentacja: https://github.com/JuliaGraphs/LightGraphs.jl
using GraphPlot #biblioteka umozliwia wygodna wizualizacje grafu
using MetaGraphs #dzieki tej bibliotece mozliwe jest przechowywanie informacji w wezlach grafu
using Compose #biblioteka pozwalajaca na zapisanie wykresu nas dysku (uwaga: do działania może wymagać dodania bibliotek Gadfly, Cairo i Fontconfig)
using Colors #biblioteka potrzebna do pokolorowania grafu

####### Parametry #######
dist = Normal(0.5,0.25); #mi - średnia, sigma - odchylenie standardowe, a więc oczekujemy wartości między 0.25 a 0.75
n_nodes = 10;
n_edges = 7;
rew_prob = 0.15; # prawdopodobieństwo zarażenia
per_volunteers = 0.2; # Liczba wolontariuszy (zarażonych) na osobę
infection_duration = 10; # Czas trwania infekcji
per_vaccinated = 0.2; # Liczba osób zaszczepionych
########################
#funkcja ktora tworzy odpowiednia siec

function generate_social_network(n_nodes, n_edges, rew_prob, dist)
	graph = MetaGraph(watts_strogatz(n_nodes, n_edges, rew_prob)) #tworzymy graf
    for i = 1:n_nodes # Inicjalizujemy wartości wszystkich osób
		#dodajemy do niego parametry opisujace agentow. Ich wewnetrzna motywacje do dzialania
		#(w SIR bedzie to wewnętrzna odporność), wskaznik tego czy sa aktualnie aktywni (zarażeni), odporni na infekcję, ile dni zarażony
		set_props!(graph,i,Dict(:exposed_to_infection=>rand(dist), :active => 0, :immune => 0, :inf_days => 0))
    end
    return graph
end

######################
# funkcja inicjujaca symulacje, tworzaca graf i poczatkowo aktywnych agentow

function initialize(n_nodes, n_edges, rew_prob, dist, per_volunteers)
	network = generate_social_network(n_nodes, n_edges, rew_prob, dist) #wywolujemy funkcje tworzaca graf
	for i = 1:n_nodes #sprawdzamy czy nie istnieja agenci aktywni od poczatku
		if get_prop(network ,i, :exposed_to_infection)  >= 1 # funkcja get_prop wyciaga odpowedni argument z wierzcholka
            set_prop!(network ,i, :active, 1) #set_prop zmienia lub dodaje nowy parametr do wierzcholka
        end
    end
    volunteers = rand(1:n_nodes,Int(round(per_volunteers*n_nodes))) #losowo wybieramy agentow, ktorzy beda aktywni od poczatku
    for j in volunteers
        set_prop!(network ,j, :active, 1) # Dla wylosowanych agentów ustawiamy parametr active na true
    end
    return network # Zwracamy zainicjalizowaną siec
end


#####################


function is_active(graph)
    final_event = 0 #zmienna pomocnicza sterujaca symulacja. Gdy ma wartosc 0 to wiemy, ze w symulacji nic juz sie nie zmienia i nie ma koniecznosci jej dalej kontynuowac
    for i = 1:nv(graph)
        if get_prop(graph ,i, :active) == 0
           external_motivation =  - (1 - sum(get_prop(graph ,j, :active)  for j in neighbors(graph,i)) / length(neighbors(graph,i))) #wyliczamy zewnetrzna motywacje do dzialania. Przyjmuje ona wartosc od -1 do 0 i rosnie gdy sasiedzi agenta staja sie aktywni
           if get_prop(graph ,i, :exposed_to_infection) + external_motivation > 0 #sprawdzamy czy suma motywacji agenta jest wieksza od 0
                set_prop!(graph ,i,:active, 1) #jesli tak to staje sie on aktywny
                final_event = 1 #a symulacja trwa dalej
            end
        end
    end
    return final_event
end

############
# funkcja sterujaca symulacja
function run_simulation(n_nodes, n_edges, rew_prob, dist, per_volunteers, infection_duration, per_vaccinated, max_iter = 1, plotting = true)
	network = initialize(n_nodes, n_edges, rew_prob, dist, per_volunteers) #tworzymy siec
	active_beginning = sum(get_prop(network ,j, :active)  for j = 1: nv(network)) # bierzemy sumę aktywnych agentów
    for i = 1:max_iter #zaczynamy symulacje
        done = is_active(network)
        if done == 1 #jezeli zmienna final_event jest rowna 0 oznacza to, ze w symulacji nic juz sie nie dzieje - nie ma sensu jej kontynuowac
			break
        end
    end
    active_end = sum(get_prop(network ,j, :active)  for j = 1:nv(network))
	if plotting
		membership = [get_prop(network ,j, :active)  for j = 1:nv(network)] .+ 1 #tworzymy wektor 1 i 2 oznaczajacy nieaktywnych (1) i aktywnych (2) agentow
		nodecolor = [colorant"lightseagreen", colorant"magenta"] #dodajemy kolory lightseagreen dla nieaktywnych i magenta dla aktywnych
		nodefillc = nodecolor[membership] #kojarzymy kolory z wezlami grafu
		#tworzymy rysunek:
		g = gplot(network, layout=spring_layout, nodefillc=nodefillc)
		draw(SVG("graph.svg", 16cm, 16cm), g)
	end
	return active_beginning, active_end
end

run_simulation(n_nodes, n_edges, rew_prob, dist, per_volunteers, infection_duration, per_vaccinated)
