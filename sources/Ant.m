classdef Ant
    properties
        prevLocation % Needed to link pheromone particles
        location % Position in absolute coordinates.
        velocityVector % Vector composed from Vr Vc Vk.
        carryingFood % Bool
        followingPheromonePath % Bool
        goingToNestDirectly % Bool
        LandmarkRecognized % Bool
        viewRange % How far an ants can "see"
        pheromoneIntensityToFollow % From which intensity value the ant
                                   % starts to follow a pheromone path
        pheromoneIntensity % How intense is the pheromone particle released
        problemEncoutered % String containing the type of problem
                          % encountered. Empty string means
                          % no problem encountered.
        globalVector % Vector pointing directly to the nest
        storedLandmarksMap % Struct containing Landamrks map,
                           % used to do a similarity check.
        lookingFor % String witch says what the ant is looking for.
    end
    
    %-- NOTE: the non static methods requires always an argument.
    %-- This is because matlab passes secretely the istance on which
    %-- the method is called as an argument.
    %-- Thus the method looks like this: function my_method(this)
    %-- and the call to the method is: obj.my_method()
    methods
        
        % Needed to preallocate an array of ants.
        function antsArr = Ant(F)
            if nargin ~= 0 % Allow nargin == 0 syntax.
                m = size(F,1);
                n = size(F,2);
                antsArr(m,n) = Ant; % Preallocate object array.
            end
        end
        
        % Main behaviour, simply call this at each step.
        % It does all the things an ant should do automatically.
        function [this ground] = performCompleteStep(this,ground,deltaT)
            global dt;
            dt = deltaT;
            % normalize the velocity vector
            v = this.velocityVector(1:2);
            v = v./norm(v);
            this.velocityVector(1:2) = v;
            % end
            ground = this.releasePheromone(ground);
            this = this.learnLandmark(ground);
            if ~isempty(this.lookingFor)
                this = this.lookForSomething(ground);
            else
                if ground.isLocationAtNest(this.location)
                    this.carryingFood = 0;
                    this.followingPheromonePath = 1;
                    this = this.stepBack;
                elseif ground.isLocationAtFoodSource(this.location)
                    this.carryingFood = 1;
                    this.goingToNestDirectly = true;
                    this.lookingFor = 'nest';
                    this = this.backToNestDirectly;
                elseif this.followingPheromonePath
                    this = this.followPheromonePath(ground);
                end
            end
            this = this.updateGlobalVector;     
        end
        
        % This method update the location of the ant using velocity vector
        % information
        function this = updateLocation(this)
            global dt;
            v = this.velocityVector(1:2);
            theta = vector2angle(v);
            yPart = sin(theta)*this.velocityVector(3)*dt;
            xPart = cos(theta)*this.velocityVector(3)*dt;
            this.prevLocation = this.location;
            this.location = this.location + [xPart;yPart];
        end
        
        % This method performs a single step in the random walk of an ant.
        function this = randomWalkStep(this,ground)
            v = this.velocityVector(1:2);
            nd = ground.nestLocation-this.location;
            d = norm(nd)/50;
            weightedVector = v./(d+0.00001)+nd.*d;
            weightedVector = weightedVector./norm(weightedVector);
            weightedAngle = vector2angle(weightedVector);
            angle = normrnd(weightedAngle,0.5); % choose an angle, with normal distr.
            yPart = sin(angle);
            xPart = cos(angle);
            this.velocityVector(1:2) = [xPart;yPart];
            this = this.updateLocation;
        end
        
        % This method makes the ant do a step directly straight to some
        % point. If the target is in range, it stops there.
        function this = stepStraightTo(this,point)
            global dt;
            v = point - this.location;
            if norm(v) < this.velocityVector(3)*dt
                if strcmp(this.lookingFor,'nest')
                    this.goingToNestDirectly = false;
                end
                this.lookingFor = '';
                this.prevLocation = this.location;
                this.location = point;
            else
                this.velocityVector = this.velocityVector+[v;0];
                this = this.updateLocation;
            end
        end
        
        function this = followPheromonePath(this,ground)
            [bool particle] = ground.hasPheromoneInLocation(this.location);
            if bool
                if this.carryingFood
                    this.prevLocation = this.location;
                    this.location = particle.next.location;
                else
                    this.prevLocation = this.location;
                    this.location = particle.prev.location;
                end
            else
                this = this.randomWalkStep(ground);
            end
        end
        
        % This method makes the ant go back to its previous position
        function this = stepBack(this)
            aux = this.location;
            this.location = this.prevLocation;
            this.prevLocation = aux;
        end
        
        % This method release pheromone on the ground, in the current and
        % position.
        function ground = releasePheromone(this,ground)
            pheromoneParticle = PheromoneParticle;
            pheromoneParticle.location = this.location;
            pheromoneParticle.intensity = this.pheromoneIntensity;
            arr = ground.pheromoneParticles; % arr just to abbreviate next line
            [bool prevParticle positionInArray] = ground.hasPheromoneInLocation(pheromoneParticle.location);
            if bool
                newPheromoneParticle = ...
                    arr(positionInArray).mergeWhithParticle(pheromoneParticle);
                arr(positionInArray) = newPheromoneParticle;
                ground.pheromoneParticles = arr;
            else
                [bool prevParticle positionInArray] = ground.hasPheromoneInLocation(this.prevLocation);
                prevParticle = prevParticle.setNext(pheromoneParticle);
                pheromoneParticle = pheromoneParticle.setPrev(prevParticle);
                arr(positionInArray) = prevParticle;
                ground.pheromoneParticles = [arr;pheromoneParticle];
            end
        end
        
        % This method updates the global vector after the ant moved.
        function this = updateGlobalVector(this)
            v = this.location-this.prevLocation;
            this.globalVector = this.globalVector-v;            
        end
        
        % This method tries to recognize a landmark, checking in the
        % lanmark array.
        function this = recognizeLandmark(this,ground)
            disp('recognizeLandmark to implement!');
        end
        
        % This method makes the ant go back to the nest directly using the
        % global vector.
        function this = backToNestDirectly(this)
            this.velocityVector(1:2) = this.globalVector;
            this = this.updateLocation;
        end
        
        % This method look for something. What is looked for is stored in
        % the "lookingFor" variable. Basically it performs a randomWalkStep
        % if the ant can't see what is looking for, else it changes
        % behaviour of the ant. The three options are 'food' or 'nest'.
        function this = lookForSomething(this,ground)
            if strcmp(this.lookingFor,'food')
                if norm(ground.foodSourceLocation-this.location) < this.viewRange
                    this = this.stepStraightTo(ground.foodSourceLocation);
                else
                     % also if the ant can't see the food source, maybe
                     % the ant can see a strong pheromone path
                     auxParts = ground.getParticlesInRange(this);
                     for i = 1 : length(auxParts)
                        if norm(auxParts(i).location-ground.nestLocation)~=0 && ...
                           auxParts(i).intensity >= this.pheromoneIntensityToFollow
                            this = this.stepStraightTo(auxParts(i).location);
                            return;
                        end
                     end
                     this = this.randomWalkStep(ground);
                end
            elseif strcmp(this.lookingFor,'nest')
                if norm(ground.nestLocation-this.location) < this.viewRange
                    this = this.stepStraightTo(ground.nestLocation);
                elseif this.goingToNestDirectly
                    this = this.backToNestDirectly;
                else
                    this = this.randomWalkStep(ground);
                end
            end
        end
        
        % This method look for a landmark, if it founds some it stores them
        % in the landmark array.
        function this = learnLandmark(this,ground)
            %disp('learnLandmark to implement!');
        end
        
        % This method is a problem handler. If one of the other methods
        % encounters a problem, it would pass the problem to this problem
        % handler.
        function this = problemHandler(this,problem,ground)
            disp('ProblemHandler to implement!');
        end
        
        % Build an ant
        function this = setUp(this,ground)
            v = ([rand;rand]).*2-1;
            v = v./norm(v);
            v = [v;0.125];
            this.velocityVector = v;
            this.carryingFood = 0;
            this.followingPheromonePath = 0;
            this.LandmarkRecognized = 0;
            this.viewRange = normrnd(3,0.1);
            this.pheromoneIntensity = 150;
            this.problemEncoutered = '';
            this.globalVector = [0;0];
            this.storedLandmarksMap = [];
            this.lookingFor = 'food';
            this.prevLocation = nan;
            this.location = ground.nestLocation;
            this.pheromoneIntensityToFollow = 300;
        end
        
    end
end



