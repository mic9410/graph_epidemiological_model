import Pkg;
Pkg.build("CodecZlib")
Pkg.add("Distributions")
Pkg.add("LightGraphs")
Pkg.add("MetaGraphs")
Pkg.add("GraphPlot")
Pkg.add("Compose")
Pkg.add("Colors")
Pkg.add("GR")
Pkg.add("Plots")
using GR
using Plots
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
per_infected = 0.45; # Liczba zarażonych na osobę
infection_duration = 10; # Czas trwania infekcji
per_vaccinated = 0.2; # Liczba osób zaszczepionych
########################
#funkcja ktora tworzy odpowiednia siec

function generate_social_network(n_nodes, n_edges, rew_prob, dist)
	graph= MetaGraph(watts_strogatz(n_nodes, n_edges, rew_prob)) #tworzymy graf
    for i = 1:n_nodes # Inicjalizujemy wartości wszystkich osób
		#dodajemy do niego parametry opisujace agentow. Ich wewnetrzna motywacje do dzialania
		#(w SIR bedzie to wewnętrzna odporność), wskaznik tego czy sa aktualnie aktywni (zarażeni), odporni na infekcję, ile dni zarażony
		set_props!(graph,i,Dict(:exposed_to_infection=>rand(dist), :infected => 0, :immune => 0, :inf_days => 0, :n_color => 0))
    end
    return graph
end

######################
# funkcja inicjujaca symulacje, tworzaca graf i poczatkowo zarażone osoby
function initialize(n_nodes, n_edges, rew_prob, dist, per_infected)
	network = generate_social_network(n_nodes, n_edges, rew_prob, dist) #wywolujemy funkcje tworzaca graf
	for i = 1:n_nodes #sprawdzamy czy nie istnieja osoby chore od początku
		if get_prop(network ,i, :exposed_to_infection)  >= 1
			set_prop!(network ,i, :infected, 1) #oznaczamy osobę jako zarażoną
			set_prop!(network ,i, :n_color, 1)
		end
    end
    infected = rand(1:n_nodes,Int(round(per_infected*n_nodes))) #losowo wybieramy osoby chore od początku
    for j in infected
        set_prop!(network ,j, :infected, 1)
		set_prop!(network ,j, :n_color, 1)
	end

	immune_candidates = Int[]
	for j in 1:n_nodes
		if get_prop(network ,j, :infected) == 0	# osoba nie może być jednocześnie chora i odporna, dlatego należy odfiltrować osoby chore
			push!(immune_candidates, j) # numery wierzchołków - kandydatów do szczepienia zapisujemy w tabeli immune_candidates
		end
	end

	#losowo wybieramy osoby, ktorzy beda zainfekowane od poczatku
	immuned = rand(1:length(immune_candidates),Int(round(per_vaccinated*length(immune_candidates))))

	# Spośród kandydatów do szczepienia wybieramy zbiór osób które zostaną zaszczepione
	for j in 1:length(immuned)
		set_prop!(network ,immune_candidates[immuned[j]], :immune, 1)
		set_prop!(network ,immune_candidates[immuned[j]], :n_color, 2)
	end

	return network # Zwracamy zainicjalizowaną siec
end


#####################
function is_active(graph, infection_duration, iteration)
    final_event = 0
    for i = 1:nv(graph)
        if get_prop(graph, i, :infected) == 0 & get_prop(graph, i, :immune) == 0
           external_motivation = - (1 - sum(get_prop(graph, j, :infected)  for j in neighbors(graph,i)) / length(neighbors(graph,i)))
           if get_prop(graph,i, :exposed_to_infection) + external_motivation > 0 & get_prop(graph,i, :n_color) != 2 #Czy osoba może być chora i nie jest odporna
                set_prop!(graph, i, :infected, 1) #jesli tak to staje sie zainfekowana
				set_prop!(graph, i, :inf_days, 1) #pierwszy dzień infekcji
				set_prop!(graph ,i, :n_color, 1)
				final_event = 1 #... a symulacja trwa dalej
            end
		elseif get_prop(graph, i, :infected) == 1 & get_prop(graph, i, :inf_days) < infection_duration
			set_prop!(graph, i, :inf_days, get_prop(graph, i, :inf_days) + 1)		#Osoba w trakcie choroby
			final_event = 1 #... a symulacja trwa dalej

		elseif get_prop(graph, i, :infected) == 1 & get_prop(graph, i, :inf_days) == infection_duration
			set_prop!(graph, i, :inf_days, 0) #infekcja się kończy
			set_prop!(graph, i, :infected, 0) #pacjent zdrowieje...
			set_prop!(graph, i, :immune, 1) #... i nabywa odporność
			set_prop!(graph ,i, :n_color, 2)
			final_event = 1 #a symulacja trwa dalej
		end
	end
	return final_event #Wszyscy zdrowi lub odporni
end

############
# funkcja sterujaca symulacja
function run_simulation(n_nodes, n_edges, rew_prob, dist, per_infected, infection_duration, per_vaccinated, max_iter = 1000)
	network = initialize(n_nodes, n_edges, rew_prob, dist, per_infected) #tworzymy siec
	active_beginning = sum(get_prop(network ,j, :infected)  for j = 1: nv(network)) # bierzemy sumę aktywnych agentów

	#tworzymy pierwszy
	membership = [get_prop(network ,j, :n_color)  for j = 1:nv(network)] .+ 1 #tworzymy wektor 1, 2 i 3 oznaczajacy zdrowych (1), chorych (2) i odpornych (3)
	nodecolor = [colorant"chartreuse3", colorant"red3", colorant"deepskyblue3"] #dodajemy kolory
	nodefillc = nodecolor[membership] #kojarzymy kolory z wezlami grafu
	g = gplot(network, layout=spring_layout, nodefillc=nodefillc)
	draw(SVG("start.svg", 16cm, 16cm), g)

    for i = 1:max_iter #zaczynamy symulacje
        result = is_active(network, infection_duration, i)
		if result == 0
			break
        end
    end
    active_end = sum(get_prop(network ,j, :infected)  for j = 1:nv(network))
	# Końcowy rysunek
	g = gplot(network, layout=spring_layout, nodefillc=nodefillc)
	draw(SVG("end.svg", 16cm, 16cm), g)

	return active_beginning, active_end
end

run_simulation(n_nodes, n_edges, rew_prob, dist, per_infected, infection_duration, per_vaccinated)
